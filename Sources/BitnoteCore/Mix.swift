/// Sum mic + sys samples with soft clipping when |sum| > 1.0.
public func mix(mic: [Float], sys: [Float]) -> [Float] {
    let count = max(mic.count, sys.count)
    var out = [Float](repeating: 0, count: count)
    for i in 0..<count {
        let m = i < mic.count ? mic[i] : 0
        let s = i < sys.count ? sys[i] : 0
        let sum = m + s
        let absSum = abs(sum)
        out[i] = absSum > 1.0 ? sum / absSum : sum
    }
    return out
}
