@preconcurrency import AVFoundation
import ScreenCaptureKit
import CoreMedia
import CoreAudio
import AppKit
import BitnoteCore

// MARK: - AudioWriter (ring buffers + timer-driven mixing)

private final class AudioWriter: @unchecked Sendable {
    var outputFormat: AVAudioFormat?
    var micConverter: AVAudioConverter?
    var sysConverter: AVAudioConverter?

    let mixQueue = DispatchQueue(label: "com.bitnote.mixQueue", qos: .userInteractive)

    private var audioFile: AVAudioFile?
    private var micRing = BitnoteCore.RingBuffer(capacity: 48_000)  // 2s at 24kHz
    private var sysRing = BitnoteCore.RingBuffer(capacity: 48_000)

    private var mixTimer: DispatchSourceTimer?
    private let mixIntervalSamples = 2400  // 100ms at 24kHz

    // MARK: - Start / Stop

    func startWriting(to url: URL, format: AVAudioFormat) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderBitRateKey: 32000,
            AVEncoderBitRateStrategyKey: AVAudioBitRateStrategy_VariableConstrained
        ]
        audioFile = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        micRing = BitnoteCore.RingBuffer(capacity: 48_000)
        sysRing = BitnoteCore.RingBuffer(capacity: 48_000)

        let timer = DispatchSource.makeTimerSource(queue: mixQueue)
        timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.drainAndMix()
        }
        timer.resume()
        mixTimer = timer
    }

    func stopWriting() {
        mixTimer?.cancel()
        mixTimer = nil
        // Final flush
        drainAndMix()
        audioFile = nil
    }

    // MARK: - Enqueue

    func enqueueMicSamples(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        micRing.write(Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength))))
    }

    func enqueueSysSamples(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        sysRing.write(Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength))))
    }

    // MARK: - Mix & Write

    private func drainAndMix() {
        guard let fmt = outputFormat, let file = audioFile else { return }

        let samplesToRead = mixIntervalSamples
        guard micRing.count > 0 || sysRing.count > 0 else { return }

        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(samplesToRead)),
              let outData = outBuffer.floatChannelData?[0] else { return }

        let micSamples = micRing.read(count: samplesToRead)
        let sysSamples = sysRing.read(count: samplesToRead)

        let frameCount = max(micSamples.count, sysSamples.count)
        guard frameCount > 0 else { return }

        let mixed = mix(mic: micSamples, sys: sysSamples)
        for i in 0..<frameCount {
            outData[i] = mixed[i]
        }
        outBuffer.frameLength = AVAudioFrameCount(frameCount)

        do {
            try file.write(from: outBuffer)
        } catch {
            print("[Bitnote] AVAudioFile write error: \(error)")
        }
    }

    // MARK: - Convert to mono

    func convertToMono(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format.channelCount == UInt32(targetFormat.channelCount) &&
           buffer.format.sampleRate == targetFormat.sampleRate {
            return buffer
        }

        if sysConverter == nil || sysConverter!.inputFormat != buffer.format {
            sysConverter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }
        guard let converter = sysConverter else { return nil }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else { return nil }

        var error: NSError?
        var consumed = false
        converter.convert(to: outBuffer, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            status.pointee = .haveData; consumed = true; return buffer
        }
        return (error == nil && outBuffer.frameLength > 0) ? outBuffer : nil
    }
}

@MainActor
final class AudioEngineManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTimeString = "00:00"
    @Published var blinkState = false

    private var avAudioEngine: AVAudioEngine?
    private var scStream: SCStream?
    private let writer = AudioWriter()

    private var recordingStartDate: Date?
    private var timerTask: Task<Void, Never>?

    private let targetSampleRate: Double = 24000
    private let targetChannels: AVAudioChannelCount = 1

    private(set) var outputURL: URL?

    func startRecording(to url: URL, deviceUID: String? = nil) async throws {
        guard !isRecording else { return }
        outputURL = url

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: false
        )!
        writer.outputFormat = targetFormat
        writer.micConverter = nil
        writer.sysConverter = nil

        try writer.startWriting(to: url, format: targetFormat)

        try startMicCapture(deviceUID: deviceUID)
        try await startSystemAudioCapture()

        isRecording = true
        recordingStartDate = Date()
        startTimer()
    }

    func stopRecording() async {
        guard isRecording else { return }
        isRecording = false
        timerTask?.cancel()
        timerTask = nil
        elapsedTimeString = "00:00"
        blinkState = false

        avAudioEngine?.inputNode.removeTap(onBus: 0)
        avAudioEngine?.stop()
        avAudioEngine = nil

        try? await scStream?.stopCapture()
        scStream = nil

        let w = writer
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            w.mixQueue.async {
                w.stopWriting()
                continuation.resume()
            }
        }
    }

    // MARK: - Mic Capture

    private func startMicCapture(deviceUID: String? = nil) throws {
        let engine = AVAudioEngine()
        avAudioEngine = engine

        if let uid = deviceUID,
           uid != "__system_default__",
           !uid.isEmpty,
           let audioDeviceID = coreAudioDeviceID(forUID: uid) {
            try engine.inputNode.auAudioUnit.setDeviceID(audioDeviceID)
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let targetFormat = writer.outputFormat!

        writer.micConverter = AVAudioConverter(from: inputFormat, to: targetFormat)

        let w = writer
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            w.mixQueue.async {
                guard let conv = w.micConverter else { return }
                let ratio = targetFormat.sampleRate / buffer.format.sampleRate
                let outCap = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
                guard let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCap) else { return }
                var error: NSError?
                var consumed = false
                conv.convert(to: outBuf, error: &error) { _, status in
                    if consumed { status.pointee = .noDataNow; return nil }
                    status.pointee = .haveData; consumed = true; return buffer
                }
                if error == nil && outBuf.frameLength > 0 {
                    w.enqueueMicSamples(outBuf)
                }
            }
        }
        try engine.start()
    }

    // MARK: - System Audio Capture

    private func startSystemAudioCapture() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw NSError(domain: "Bitnote", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = Int(targetSampleRate)
        config.channelCount = Int(targetChannels)
        config.width = 2
        config.height = 2

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        scStream = stream
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: writer.mixQueue)
        try await stream.startCapture()
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, let start = self.recordingStartDate else { continue }
                let elapsed = Int(Date().timeIntervalSince(start))
                self.elapsedTimeString = String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
                self.blinkState.toggle()
            }
        }
    }
}

// MARK: - SCStreamOutput

extension AudioEngineManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let pcmBuffer = sampleBuffer.toPCMBuffer() else { return }

        let w = writer
        if let targetFmt = w.outputFormat,
           let mono = w.convertToMono(pcmBuffer, targetFormat: targetFmt) {
            w.enqueueSysSamples(mono)
        } else {
            w.enqueueSysSamples(pcmBuffer)
        }
    }
}

// MARK: - CMSampleBuffer → AVAudioPCMBuffer (using Apple's proper API)

extension CMSampleBuffer {
    func toPCMBuffer() -> AVAudioPCMBuffer? {
        guard let fmtDesc = CMSampleBufferGetFormatDescription(self),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmtDesc) else { return nil }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(self))
        guard frameCount > 0 else { return nil }

        var asbdCopy = asbd.pointee
        guard let format = AVAudioFormat(streamDescription: &asbdCopy) else { return nil }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            self,
            at: 0,
            frameCount: Int32(frameCount),
            into: buffer.mutableAudioBufferList
        )
        guard status == noErr else { return nil }

        return buffer
    }
}

// MARK: - Core Audio UID → AudioDeviceID

private func coreAudioDeviceID(forUID uid: String) -> AudioDeviceID? {
    var deviceID = AudioDeviceID(kAudioObjectUnknown)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let cfUID = uid as CFString
    var mutableCFUID = cfUID
    let status = withUnsafeMutablePointer(to: &mutableCFUID) { ptr in
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            UInt32(MemoryLayout<CFString>.size),
            ptr,
            &size,
            &deviceID
        )
    }
    guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
    return deviceID
}
