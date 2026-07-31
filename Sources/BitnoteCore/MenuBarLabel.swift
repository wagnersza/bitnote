import Foundation

public func menuBarLabel(isRecording: Bool, elapsed: String) -> (symbol: String, text: String?) {
    if isRecording {
        return ("record.circle.fill", "REC \(elapsed)")
    }
    return ("record.circle", nil)
}
