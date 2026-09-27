import SpriteKit
import UIKit

/// Tile textures for every cell state, drawn once with Core Graphics.
/// Port of `drawCell` from the web version. Mowing a cell just swaps its tile group.
final class LawnTiles {
    let tileSet: SKTileSet
    private let uncut: [SKTileGroup]
    private let stripes: [[SKTileGroup]]   // [direction 0...3][variant]
    private let flowers: [SKTileGroup]
    private let wreck: SKTileGroup
    private let paths: [SKTileGroup]       // bit 1 = vertical joint, bit 2 = horizontal joint
    private let mulch: [SKTileGroup]

    static let stripeColors: [UInt32] = [0xa4dc6c, 0x6cb041, 0x94d25d, 0x78ba4b] // right, left, down, up
    static let flowerColors: [UInt32] = [0xff6fa8, 0xffd23a, 0xffffff, 0xb77cff, 0xff8a3d]

    private static let px: CGFloat = 16  // texture size in points

    init(unit: CGFloat) {
        func group(_ draw: (CGContext) -> Void) -> SKTileGroup {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: CGSize(width: LawnTiles.px, height: LawnTiles.px), format: format).image { ctx in
                draw(ctx.cgContext)
            }
            let texture = SKTexture(image: image)
            let def = SKTileDefinition(texture: texture, size: CGSize(width: unit, height: unit))
            return SKTileGroup(tileDefinition: def)
        }
        func rect(_ c: CGContext, _ hex: UInt32, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, alpha: CGFloat = 1) {
            c.setFillColor(UIColor(hex: hex, alpha: alpha).cgColor)
            c.fill(CGRect(x: x, y: y, width: w, height: h))
        }
        let S = LawnTiles.px

        let uncutG = (0..<4).map { v in
            group { c in
                rect(c, v % 2 == 0 ? 0x3a7b28 : 0x357425, 0, 0, S, S)
                let seed = 1000 + v * 37
                for k in 0..<6 {
                    let col: UInt32 = k % 3 == 0 ? 0x58a23c : (k % 3 == 1 ? 0x2a6120 : 0x4a9132)
                    rect(c, col, CGFloat(cellHash(seed, k + 2)) * (S - 2), CGFloat(cellHash(seed, k + 11)) * (S - 6), 2, 6)
                }
            }
        }

        let stripesG = LawnTiles.stripeColors.enumerated().map { (d, hex) in
            (0..<3).map { v in
                group { c in
                    rect(c, hex, 0, 0, S, S)
                    let seed = 2000 + d * 11 + v * 101
                    c.setFillColor(UIColor(white: 0, alpha: 0.06).cgColor)
                    c.fill(CGRect(x: CGFloat(cellHash(seed, 3)) * (S - 2), y: CGFloat(cellHash(seed, 4)) * (S - 2), width: 2, height: 2))
                    c.setFillColor(UIColor(white: 1, alpha: 0.1).cgColor)
                    c.fill(CGRect(x: CGFloat(cellHash(seed, 5)) * (S - 2), y: CGFloat(cellHash(seed, 6)) * (S - 2), width: 2, height: 2))
                }
            }
        }

        let flowersG = LawnTiles.flowerColors.enumerated().map { (n, hex) in
            group { c in
                rect(c, 0x5b3d28, 0, 0, S, S)
                let seed = 3000 + n * 53
                rect(c, 0x4a311f, CGFloat(cellHash(seed, 7)) * 12, CGFloat(cellHash(seed, 8)) * 12, 3, 3)
                rect(c, 0x2f7a2a, 3, 7, 10, 3)
                for k in 0..<2 {
                    let fx = 3 + CGFloat(cellHash(seed, 20 + k)) * 10, fy = 3 + CGFloat(cellHash(seed, 30 + k)) * 10
                    c.setFillColor(UIColor(hex: hex).cgColor)
                    c.fillEllipse(in: CGRect(x: fx - 3.2, y: fy - 3.2, width: 6.4, height: 6.4))
                    c.setFillColor(UIColor(hex: 0xf5b82e).cgColor)
                    c.fillEllipse(in: CGRect(x: fx - 1.2, y: fy - 1.2, width: 2.4, height: 2.4))
                }
            }
        }

        let wreckG = group { c in
            rect(c, 0x5b3d28, 0, 0, S, S)
            rect(c, 0x4a311f, 9, 3, 3, 3)
            rect(c, 0x8a6a3a, 4, 6, 2, 5)
            rect(c, 0x8a6a3a, 10, 4, 2, 6)
        }

        let pathsG = (0..<4).map { bits in
            group { c in
                rect(c, 0xd3ccba, 0, 0, S, S)
                c.setFillColor(UIColor(white: 0, alpha: 0.05).cgColor)
                c.fill(CGRect(x: CGFloat(cellHash(4000 + bits, 12)) * 13, y: CGFloat(cellHash(4000 + bits, 13)) * 13, width: 3, height: 3))
                c.setFillColor(UIColor(red: 80 / 255, green: 70 / 255, blue: 50 / 255, alpha: 0.25).cgColor)
                if bits & 1 != 0 { c.fill(CGRect(x: 0, y: 0, width: 1, height: S)) }
                if bits & 2 != 0 { c.fill(CGRect(x: 0, y: 0, width: S, height: 1)) }
            }
        }

        let mulchG = (0..<3).map { v in
            group { c in
                let seed = 5000 + v * 17
                rect(c, 0x6a4630, 0, 0, S, S)
                rect(c, 0x7d5539, CGFloat(cellHash(seed, 14)) * 12, CGFloat(cellHash(seed, 15)) * 12, 4, 2)
                rect(c, 0x553622, CGFloat(cellHash(seed, 16)) * 12, CGFloat(cellHash(seed, 17)) * 12, 3, 3)
            }
        }

        var all: [SKTileGroup] = uncutG + flowersG + pathsG + mulchG + [wreckG]
        for s in stripesG { all += s }
        uncut = uncutG
        stripes = stripesG
        flowers = flowersG
        wreck = wreckG
        paths = pathsG
        mulch = mulchG
        tileSet = SKTileSet(tileGroups: all)
    }

    func group(for lawn: Lawn, index i: Int) -> SKTileGroup {
        switch lawn.grid[i] {
        case Cell.grass:
            let s = Int(lawn.cut[i])
            if s == 0 { return uncut[Int(cellHash(i, 1) * 4) % 4] }
            return stripes[s - 1][Int(cellHash(i, 3) * 3) % 3]
        case Cell.flower:
            return flowers[Int(cellHash(i, 9) * 5) % 5]
        case Cell.wreck:
            return wreck
        case Cell.path:
            let col = i % lawn.W, row = i / lawn.W
            return paths[(col % 4 == 0 ? 1 : 0) | (row % 4 == 0 ? 2 : 0)]
        default:
            return mulch[Int(cellHash(i, 14) * 3) % 3]
        }
    }

    /// Flat color per cell for the minimap.
    static func minimapColor(for lawn: Lawn, index i: Int) -> CGColor {
        let hex: UInt32
        switch lawn.grid[i] {
        case Cell.grass:
            let s = Int(lawn.cut[i])
            hex = s == 0 ? 0x2f6a22 : stripeColors[s - 1]
        case Cell.flower: hex = 0xd9679a
        case Cell.wreck: hex = 0x5b3d28
        case Cell.path: hex = 0xd3ccba
        case Cell.none: hex = 0x4a4038
        default: hex = 0x6a4630
        }
        return UIColor(hex: hex).cgColor
    }
}
