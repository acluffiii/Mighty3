import Foundation

/// mulberry32, bit-for-bit the same as `rngOf` in the web version,
/// so job #N generates the same yard on iOS and in the browser.
struct Mulberry32 {
    private var a: UInt32

    init(seed: UInt32) { a = seed }

    mutating func next() -> Double {
        a = a &+ 0x6D2B79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4294967296
    }
}

/// Stable per-cell noise in [0, 1). Same as `hash(i, k)` in the web version.
func cellHash(_ i: Int, _ k: Int) -> Double {
    let ii = UInt32(truncatingIfNeeded: i), kk = UInt32(truncatingIfNeeded: k)
    var h = ii &* 374761393 &+ kk &* 668265263
    h = (h ^ (h >> 13)) &* 1274126177
    return Double(h ^ (h >> 16)) / 4294967296
}
