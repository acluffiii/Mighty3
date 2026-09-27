import Foundation

/// Cell types in the lawn grid.
enum Cell {
    static let none: UInt8 = 0    // under the house or the pool water
    static let grass: UInt8 = 1
    static let flower: UInt8 = 2
    static let path: UInt8 = 3    // sidewalk, driveway, pool deck
    static let mulch: UInt8 = 4   // tree rings, around gnomes and rocks
    static let wreck: UInt8 = 5   // a flower that got mowed
}

enum SolidKind {
    case house, car, pool, tree, gnome, rock
}

/// Something the mower bumps into. Coordinates are in cells, y grows downward (same as the web version).
struct Solid {
    var kind: SolidKind
    var x: Double
    var y: Double
    var w: Double = 0        // rect solids
    var h: Double = 0
    var r: Double = 0        // round solids
    var colorIndex = 0
    var canopy = 0.0
    var tone = 0.0
    var seed = 0.0

    var isRect: Bool { kind == .house || kind == .car || kind == .pool }
}

final class Lawn {
    let W: Int
    let H: Int
    var grid: [UInt8]
    var cut: [UInt8]            // 0 = uncut, 1...4 = stripe direction (right, left, down, up)
    var solids: [Solid]
    var gold: Set<Int>          // golden dandelion cells
    let start: (x: Double, y: Double)
    let total: Int              // mowable sq ft
    let flowers: Int
    var cutCount = 0
    let demo: Bool
    let level: Int
    let name: String
    var rng: Mulberry32

    init(W: Int, H: Int, grid: [UInt8], solids: [Solid], gold: Set<Int>, start: (x: Double, y: Double),
         demo: Bool, level: Int, name: String, rng: Mulberry32) {
        self.W = W
        self.H = H
        self.grid = grid
        self.cut = [UInt8](repeating: 0, count: W * H)
        self.solids = solids
        self.gold = gold
        self.start = start
        self.demo = demo
        self.level = level
        self.name = name
        self.rng = rng
        var total = 0, flowers = 0
        for g in grid {
            if g == Cell.grass { total += 1 } else if g == Cell.flower { flowers += 1 }
        }
        self.total = max(1, total)
        self.flowers = flowers
    }

    var progress: Double { Double(cutCount) / Double(total) }
}

enum LawnGenerator {
    static let customers = ["Mrs. Okafor", "The Lindqvists", "Mr. Delgado", "Pastor Jim", "The Nakamuras",
                            "Coach Riley", "Dr. Abernathy", "The Petrovs", "Ms. Haverford", "Grandpa Lou",
                            "The Brennans", "Mayor Whitlock", "The Adeyemis", "Judge Castellano"]

    private static func jsRound(_ v: Double) -> Int { Int(floor(v + 0.5)) }

    static func make(level: Int, demo: Bool) -> Lawn {
        var rng = Mulberry32(seed: UInt32(truncatingIfNeeded: level * 9973 + (demo ? 777 : 1)))
        func r() -> Double { rng.next() }

        let W = demo ? 44 : min(28 + level * 4, 96)
        let H = demo ? 32 : min(24 + level * 3, 72)
        var grid = [UInt8](repeating: Cell.grass, count: W * H)
        var solids: [Solid] = []
        var placed: [(x: Double, y: Double, r: Double)] = []

        func inb(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < W && y < H }
        func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ v: UInt8) {
            guard w > 0, h > 0 else { return }
            for j in y..<(y + h) {
                for i in x..<(x + w) where inb(i, j) { grid[j * W + i] = v }
            }
        }
        func fillCircle(_ cx: Double, _ cy: Double, _ rad: Double, _ v: UInt8) {
            for j in Int(floor(cy - rad))...Int(ceil(cy + rad)) {
                for i in Int(floor(cx - rad))...Int(ceil(cx + rad)) {
                    let dx = Double(i) + 0.5 - cx, dy = Double(j) + 0.5 - cy
                    if inb(i, j) && dx * dx + dy * dy <= rad * rad { grid[j * W + i] = v }
                }
            }
        }

        // House along the top, flower bed in front, walk to the door, public sidewalk along the bottom.
        let hw = max(12, jsRound(Double(W) * 0.36)), hh = 6
        let hx = min(max(jsRound(Double(W - hw) / 2 + (r() - 0.5) * Double(W) * 0.25), 2), W - hw - 2)
        solids.append(Solid(kind: .house, x: Double(hx), y: 0, w: Double(hw), h: Double(hh), colorIndex: Int(r() * 5)))
        fill(hx, 0, hw, hh, Cell.none)
        fill(hx, hh, hw, 2, Cell.flower)
        let doorX = hx + hw / 2 - 1
        fill(doorX, hh, 2, 4, Cell.path)
        fill(0, H - 2, W, 2, Cell.path)

        var start = (x: 3.5, y: Double(H - 4))
        if level >= 2 && !demo {
            let dw = 5
            var dx = hx + hw + 2
            if dx + dw > W - 3 { dx = hx - 2 - dw }
            if dx >= 3 {
                fill(dx, 0, dw, H - 2, Cell.path)
                solids.append(Solid(kind: .car, x: Double(dx) + 0.8, y: 1, w: 3.4, h: 6.2, colorIndex: Int(r() * 4)))
            }
            if abs(Double(dx) + 2.5 - start.x) < 6 { start.x = Double(W) - 4.5 }
        }

        func free(_ cx: Double, _ cy: Double, _ rad: Double) -> Bool {
            if hypot(cx - start.x, cy - start.y) < rad + 5 { return false }
            for p in placed where hypot(p.x - cx, p.y - cy) < p.r + rad + 2.2 { return false }
            for j in Int(floor(cy - rad - 1))...Int(ceil(cy + rad + 1)) {
                for i in Int(floor(cx - rad - 1))...Int(ceil(cx + rad + 1)) {
                    if !inb(i, j) || grid[j * W + i] != Cell.grass { return false }
                }
            }
            return true
        }
        func spot(_ rad: Double) -> (x: Double, y: Double)? {
            for _ in 0..<80 {
                let cx = 3 + r() * Double(W - 6), cy = Double(hh + 4) + r() * Double(H - hh - 8)
                if free(cx, cy, rad) {
                    placed.append((x: cx, y: cy, r: rad))
                    return (x: cx, y: cy)
                }
            }
            return nil
        }

        if !demo {
            if level >= 5 { // backyard pool with a concrete deck
                for _ in 0..<60 {
                    let pw = 10, ph = 6
                    let px = 3 + Int(floor(r() * Double(W - pw - 6)))
                    let py = hh + 5 + Int(floor(r() * Double(H - hh - ph - 10)))
                    if free(Double(px) + Double(pw) / 2, Double(py) + Double(ph) / 2, 6.5) {
                        fill(px - 1, py - 1, pw + 2, ph + 2, Cell.path)
                        fill(px, py, pw, ph, Cell.none)
                        solids.append(Solid(kind: .pool, x: Double(px), y: Double(py), w: Double(pw), h: Double(ph)))
                        placed.append((x: Double(px) + Double(pw) / 2, y: Double(py) + Double(ph) / 2, r: 6.5))
                        break
                    }
                }
            }
            let nTrees = min((level + 1) / 2, 9)
            for _ in 0..<nTrees {
                guard let p = spot(2.2) else { continue }
                fillCircle(p.x, p.y, 2.1, Cell.mulch)
                let canopy = 3 + r() * 1.3
                solids.append(Solid(kind: .tree, x: p.x, y: p.y, r: 0.9, canopy: canopy, tone: r()))
            }
            let nBeds = level >= 2 ? min(level / 2, 6) : 0
            for _ in 0..<nBeds {
                if let p = spot(2.6) { fillCircle(p.x, p.y, 1.6 + r(), Cell.flower) }
            }
            let nGnomes = level >= 3 ? min(level - 2, 6) : 0
            for _ in 0..<nGnomes {
                guard let p = spot(1) else { continue }
                fillCircle(p.x, p.y, 0.75, Cell.mulch)
                solids.append(Solid(kind: .gnome, x: p.x, y: p.y, r: 0.45))
            }
            let nRocks = level >= 4 ? min(level - 3, 5) : 0
            for _ in 0..<nRocks {
                guard let p = spot(1) else { continue }
                fillCircle(p.x, p.y, 0.8, Cell.mulch)
                solids.append(Solid(kind: .rock, x: p.x, y: p.y, r: 0.6, seed: r()))
            }
        }

        var gold = Set<Int>()
        if !demo {
            let n = 5 + level * 2
            var k = 0
            while k < n * 20 && gold.count < n {
                let i = Int(r() * Double(grid.count))
                let gx = Double(i % W) + 0.5, gy = Double(i / W) + 0.5
                if grid[i] == Cell.grass && hypot(gx - start.x, gy - start.y) > 5 { gold.insert(i) }
                k += 1
            }
        }

        var total = 0
        for g in grid where g == Cell.grass { total += 1 }
        let who = customers[(level - 1) % customers.count]
        let whereName = total < 900 ? "front yard" : total < 1800 ? "backyard" : total < 3200 ? "corner lot" : "estate lawn"

        return Lawn(W: W, H: H, grid: grid, solids: solids, gold: gold, start: start,
                    demo: demo, level: level, name: "\(who)'s \(whereName)", rng: rng)
    }
}
