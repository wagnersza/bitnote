public struct RingBuffer {
    private var storage: [Float]
    private var readIndex = 0
    private var writeIndex = 0
    public private(set) var count = 0
    public let capacity: Int

    public init(capacity: Int) {
        self.capacity = capacity
        self.storage = [Float](repeating: 0, count: capacity)
    }

    public mutating func write(_ samples: [Float]) {
        for sample in samples {
            storage[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
            if count == capacity {
                readIndex = (readIndex + 1) % capacity
            } else {
                count += 1
            }
        }
    }

    public mutating func read(count requested: Int) -> [Float] {
        let toRead = min(requested, count)
        var result = [Float](repeating: 0, count: toRead)
        for i in 0..<toRead {
            result[i] = storage[readIndex]
            readIndex = (readIndex + 1) % capacity
        }
        count -= toRead
        return result
    }
}
