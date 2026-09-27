import SpriteKit
import UIKit

let inkColor = UIColor(hex: 0x15291a)
private let roofColors: [UInt32] = [0x8a4b3c, 0x4d5a6b, 0x6b5a45, 0x3f5d4a, 0x5b4a6e]
private let carColors: [UInt32] = [0x2b5fa8, 0xc7332b, 0xe9e4d8, 0x333a40]

// MARK: - Shape helpers

func shape(rect: CGRect, corner: CGFloat = 0, fill: UIColor, stroke: UIColor? = nil, line: CGFloat = 0) -> SKShapeNode {
    let n = corner > 0 ? SKShapeNode(rect: rect, cornerRadius: corner) : SKShapeNode(rect: rect)
    n.fillColor = fill
    n.strokeColor = stroke ?? .clear
    n.lineWidth = stroke == nil ? 0 : line
    return n
}

func shape(circle center: CGPoint, radius: CGFloat, fill: UIColor, stroke: UIColor? = nil, line: CGFloat = 0) -> SKShapeNode {
    let n = SKShapeNode(circleOfRadius: radius)
    n.position = center
    n.fillColor = fill
    n.strokeColor = stroke ?? .clear
    n.lineWidth = stroke == nil ? 0 : line
    return n
}

func shape(path: CGPath, fill: UIColor = .clear, stroke: UIColor? = nil, line: CGFloat = 0) -> SKShapeNode {
    let n = SKShapeNode(path: path)
    n.fillColor = fill
    n.strokeColor = stroke ?? .clear
    n.lineWidth = stroke == nil ? 0 : line
    n.lineCap = .round
    n.lineJoin = .round
    return n
}

extension GameScene {

    // MARK: - Scenery

    func makeHedge() -> SKNode {
        let node = SKNode()
        let W = Double(lawn.W), H = Double(lawn.H)
        node.addChild(shape(rect: jr(-2, -2, W + 4, H + 4), fill: UIColor(hex: 0x244a1d)))
        let bumps = CGMutablePath()
        func bump(_ x: Double, _ y: Double) {
            bumps.addEllipse(in: CGRect(x: (CGFloat(x) - 0.9) * U, y: (CGFloat(H - y) - 0.9) * U, width: 1.8 * U, height: 1.8 * U))
        }
        var i = -1.0
        while i <= W { bump(i, -0.9); bump(i + 0.6, H + 0.9); i += 1.2 }
        var j = -1.0
        while j <= H { bump(-0.9, j); bump(W + 0.9, j + 0.6); j += 1.2 }
        node.addChild(shape(path: bumps, fill: UIColor(hex: 0x1b3a16)))
        return node
    }

    func makeDandelion(_ i: Int) -> SKNode {
        let x = Double(i % lawn.W) + 0.5, y = Double(i / lawn.W) + 0.5
        let node = SKNode()
        node.position = sp(x, y)
        node.addChild(shape(circle: .zero, radius: 0.42 * U, fill: UIColor(hex: 0xffe680)))
        node.addChild(shape(circle: .zero, radius: 0.28 * U, fill: UIColor(hex: 0xffc21a)))
        let pulse = SKAction.sequence([.scale(to: 1.12, duration: 0.4), .scale(to: 0.88, duration: 0.4)])
        pulse.timingMode = .easeInEaseOut
        node.run(.sequence([.wait(forDuration: cellHash(i, 99) * 0.8), .repeatForever(pulse)]))
        return node
    }

    func makeSolidNode(_ s: Solid) -> SKNode {
        let node = SKNode()
        let line = U * 0.08
        switch s.kind {
        case .house:
            let roof = UIColor(hex: roofColors[s.colorIndex % roofColors.count])
            var shadowRect = jr(s.x, s.y, s.w, s.h)
            shadowRect = shadowRect.offsetBy(dx: 0.35 * U, dy: -0.45 * U)
            node.addChild(shape(rect: shadowRect, fill: UIColor(white: 0, alpha: 0.28)))
            node.addChild(shape(rect: jr(s.x, s.y, s.w, s.h / 2), fill: roof))
            node.addChild(shape(rect: jr(s.x, s.y + s.h / 2, s.w, s.h / 2), fill: roof.shaded(-0.18)))
            let shingles = CGMutablePath()
            var y = s.y + 0.5
            while y < s.y + s.h {
                shingles.move(to: sp(s.x, y))
                shingles.addLine(to: sp(s.x + s.w, y))
                y += 0.5
            }
            node.addChild(shape(path: shingles, stroke: UIColor(white: 0, alpha: 0.18), line: U * 0.05))
            let ridge = CGMutablePath()
            ridge.move(to: sp(s.x, s.y + s.h / 2))
            ridge.addLine(to: sp(s.x + s.w, s.y + s.h / 2))
            node.addChild(shape(path: ridge, stroke: roof.shaded(0.25), line: U * 0.18))
            node.addChild(shape(rect: jr(s.x + s.w * 0.78, s.y + 0.7, 1.1, 1.3), fill: UIColor(hex: 0x7b3f33)))
            node.addChild(shape(rect: jr(s.x, s.y, s.w, s.h), fill: .clear, stroke: inkColor, line: U * 0.1))

        case .car:
            let color = UIColor(hex: carColors[s.colorIndex % carColors.count])
            node.addChild(shape(rect: jr(s.x, s.y, s.w, s.h).offsetBy(dx: 0.25 * U, dy: -0.35 * U), corner: 0.8 * U,
                                fill: UIColor(white: 0, alpha: 0.25)))
            node.addChild(shape(rect: jr(s.x, s.y, s.w, s.h), corner: 0.8 * U, fill: color, stroke: inkColor, line: line))
            node.addChild(shape(rect: jr(s.x + 0.4, s.y + s.h * 0.62, s.w - 0.8, 1.2), corner: 0.3 * U, fill: UIColor(hex: 0x9fc6d8)))
            node.addChild(shape(rect: jr(s.x + 0.5, s.y + 1.1, s.w - 1, 0.8), corner: 0.3 * U, fill: UIColor(hex: 0x9fc6d8, alpha: 0.7)))

        case .pool:
            node.addChild(shape(rect: jr(s.x, s.y, s.w, s.h), fill: UIColor(hex: 0x2aa9d6)))
            let ripples = CGMutablePath()
            for k in 0..<4 {
                let yy = s.y + 1 + Double(k) * 1.3
                var x = s.x + 0.4
                ripples.move(to: sp(x, yy + sin(x * 2 + Double(k)) * 0.15))
                while x < s.x + s.w - 0.3 {
                    ripples.addLine(to: sp(x, yy + sin(x * 2 + Double(k)) * 0.15))
                    x += 0.25
                }
            }
            let rippleNode = shape(path: ripples, stroke: UIColor(white: 1, alpha: 0.45), line: U * 0.1)
            rippleNode.run(.repeatForever(.sequence([.moveBy(x: 0.3 * U, y: 0, duration: 1.5),
                                                     .moveBy(x: -0.3 * U, y: 0, duration: 1.5)])))
            node.addChild(rippleNode)
            let ring = SKNode()
            ring.position = sp(s.x + s.w * 0.7, s.y + s.h * 0.45)
            ring.addChild(shape(circle: .zero, radius: 0.6 * U, fill: UIColor(hex: 0xff6f5e)))
            ring.addChild(shape(circle: .zero, radius: 0.3 * U, fill: UIColor(hex: 0x2aa9d6)))
            ring.run(.repeatForever(.sequence([.moveBy(x: 0.8 * U, y: 0, duration: 4), .moveBy(x: -0.8 * U, y: 0, duration: 4)])))
            node.addChild(ring)
            node.addChild(shape(rect: jr(s.x, s.y, s.w, s.h), fill: .clear, stroke: inkColor, line: line))

        case .tree:
            node.addChild(shape(circle: sp(s.x + 0.6, s.y + 0.8), radius: CGFloat(s.canopy) * U, fill: UIColor(white: 0, alpha: 0.25)))
            node.addChild(shape(circle: sp(s.x, s.y), radius: CGFloat(s.r) * U, fill: UIColor(hex: 0x5a3a22)))

        case .gnome:
            node.position = sp(s.x, s.y)
            node.addChild(shape(circle: CGPoint(x: 0.15 * U, y: -0.2 * U), radius: 0.5 * U, fill: UIColor(white: 0, alpha: 0.25)))
            node.addChild(shape(circle: .zero, radius: 0.45 * U, fill: UIColor(hex: 0x2d62c9), stroke: inkColor, line: line))
            node.addChild(shape(circle: CGPoint(x: 0, y: -0.18 * U), radius: 0.28 * U, fill: .white))
            node.addChild(shape(circle: CGPoint(x: 0, y: 0.08 * U), radius: 0.3 * U, fill: UIColor(hex: 0xe2412f), stroke: inkColor, line: line))
            node.addChild(shape(circle: CGPoint(x: 0, y: -0.05 * U), radius: 0.1 * U, fill: UIColor(hex: 0xffd9b8)))

        case .rock:
            node.addChild(shape(circle: sp(s.x + 0.15, s.y + 0.2), radius: CGFloat(s.r) * U, fill: UIColor(white: 0, alpha: 0.25)))
            let path = CGMutablePath()
            let seed = Int(s.seed * 1e6)
            for k in 0..<7 {
                let a = Double(k) / 7 * 2 * .pi
                let rr = s.r * (0.8 + cellHash(k, seed) * 0.35)
                let p = sp(s.x + cos(a) * rr, s.y + sin(a) * rr)
                if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            node.addChild(shape(path: path, fill: UIColor(hex: 0x9a9a92), stroke: inkColor, line: line))
            node.addChild(shape(circle: sp(s.x - 0.15, s.y - 0.15), radius: 0.18 * U, fill: UIColor(white: 1, alpha: 0.3)))
        }
        return node
    }

    func makeCanopy(_ s: Solid) -> SKNode {
        let node = SKNode()
        let base = s.tone < 0.5 ? UIColor(hex: 0x2e6e2a) : UIColor(hex: 0x3b7d22)
        let r = CGFloat(s.canopy) * U
        node.addChild(shape(circle: sp(s.x, s.y), radius: r, fill: base.shaded(-0.2)))
        node.addChild(shape(circle: sp(s.x - 0.35, s.y - 0.35), radius: r * 0.82, fill: base))
        for k in 0..<5 {
            let a = Double(k) * 1.3 + s.tone * 6
            let c = sp(s.x - 0.5 + cos(a) * s.canopy * 0.4, s.y - 0.5 + sin(a) * s.canopy * 0.4)
            node.addChild(shape(circle: c, radius: r * 0.3, fill: base.shaded(0.18)))
        }
        return node
    }

    func wobble(_ node: SKNode?) {
        guard let node = node, node.action(forKey: "wobble") == nil else { return }
        let w = SKAction.sequence([.rotate(toAngle: 0.25, duration: 0.05), .rotate(toAngle: -0.2, duration: 0.08),
                                   .rotate(toAngle: 0.12, duration: 0.08), .rotate(toAngle: 0, duration: 0.1)])
        node.run(w, withKey: "wobble")
    }

    // MARK: - Mower

    /// Local mower coordinates: +x is forward, +y is the driver's right (as in the web version).
    func makeMower(_ st: Stats) -> SKNode {
        let tier = min(max(session?.save.tier ?? 0, 0), Catalog.tiers.count - 1)
        let t = Catalog.tiers[tier]
        let d = st.deck
        let node = SKNode()
        let line = U * 0.08
        func lr(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
            CGRect(x: CGFloat(x) * U, y: -CGFloat(y + h) * U, width: CGFloat(w) * U, height: CGFloat(h) * U)
        }
        func lp(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: CGFloat(x) * U, y: -CGFloat(y) * U) }
        func wheel(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
            node.addChild(shape(rect: lr(x - w / 2, y - h / 2, w, h), corner: 0.12 * U, fill: UIColor(hex: 0x1b1e1b)))
        }
        func head(_ x: Double, cap: UIColor) {
            node.addChild(shape(circle: lp(x, 0), radius: 0.36 * U, fill: UIColor(hex: 0xe9b38a)))
            let p = CGMutablePath()
            p.addArc(center: lp(x, 0), radius: 0.37 * U, startAngle: .pi / 2, endAngle: .pi * 1.5, clockwise: false)
            p.closeSubpath()
            node.addChild(shape(path: p, fill: cap))
        }

        node.addChild(shape(rect: lr(-1.0, -d + 0.25, 2.4, d * 2), corner: 0.4 * U, fill: UIColor(white: 0, alpha: 0.25)))

        if tier == 0 {
            let handle = CGMutablePath()
            handle.move(to: lp(-0.6, -0.55))
            handle.addLine(to: lp(-2.1, -0.45))
            handle.addLine(to: lp(-2.1, 0.45))
            handle.addLine(to: lp(-0.6, 0.55))
            node.addChild(shape(path: handle, stroke: UIColor(hex: 0x3a3f3a), line: U * 0.14))
            node.addChild(shape(rect: lr(-1.6, -0.5, 0.9, 1), corner: 0.2 * U, fill: UIColor(hex: 0x2f7a2a)))
            wheel(0.55, -d + 0.15, 0.45, 0.22); wheel(0.55, d - 0.15, 0.45, 0.22)
            wheel(-0.55, -d + 0.15, 0.45, 0.22); wheel(-0.55, d - 0.15, 0.45, 0.22)
            node.addChild(shape(rect: lr(-0.75, -d + 0.2, 1.5, d * 2 - 0.4), corner: 0.35 * U, fill: t.color, stroke: inkColor, line: line))
            node.addChild(shape(circle: .zero, radius: 0.42 * U, fill: UIColor(hex: 0xc9ccc4), stroke: inkColor, line: line))
            node.addChild(shape(circle: .zero, radius: 0.14 * U, fill: inkColor))
            head(-2.55, cap: UIColor(hex: 0x3564b5))
        } else {
            let len = tier == 3 ? 2.2 : 1.8
            let bw = tier == 3 ? 1.2 : 0.95
            let deckX = tier == 1 ? 0.0 : 0.9
            node.addChild(shape(rect: lr(deckX - 0.6, -d, 1.2, d * 2), corner: 0.4 * U, fill: UIColor(hex: 0x4b514b), stroke: inkColor, line: line))
            wheel(len - 0.3, -bw - 0.1, 0.6, 0.35); wheel(len - 0.3, bw + 0.1, 0.6, 0.35)
            wheel(-len + 0.45, -bw - 0.15, 0.9, 0.5); wheel(-len + 0.45, bw + 0.15, 0.9, 0.5)
            node.addChild(shape(rect: lr(-len, -bw, len * 2, bw * 2), corner: 0.45 * U, fill: t.color, stroke: inkColor, line: line))
            node.addChild(shape(rect: lr(len * 0.2, -bw * 0.7, len * 0.7, bw * 1.4), corner: 0.3 * U, fill: t.color.shaded(-0.2)))
            node.addChild(shape(rect: lr(-len * 0.75, -0.5, 0.9, 1), corner: 0.25 * U, fill: UIColor(hex: 0x23272a)))
            if tier == 3 {
                node.addChild(shape(rect: lr(-len * 0.9, -bw * 0.9, 1.6, bw * 1.8), corner: 0.3 * U,
                                    fill: UIColor(white: 1, alpha: 0.85), stroke: inkColor, line: line))
            } else {
                head(-len * 0.35, cap: tier == 2 ? inkColor : UIColor(hex: 0xffc92e))
            }
        }
        return node
    }

    // MARK: - Pickups and effects

    func makePowerItem(_ kind: PowerKind) -> SKNode {
        let node = SKNode()
        let r = 0.72 * U
        node.addChild(shape(circle: CGPoint(x: 0.12 * U, y: -r * 0.7), radius: r * 0.55, fill: UIColor(white: 0, alpha: 0.25)))
        let body = SKNode()
        body.addChild(shape(circle: .zero, radius: r, fill: kind.color, stroke: .white, line: 3 * camScale))
        let label = SKLabelNode(fontNamed: nil)
        label.attributedText = NSAttributedString(string: kind.glyph, attributes: [
            .font: roundedFont(r * 1.15, .black),
            .foregroundColor: UIColor.white,
        ])
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        body.addChild(label)
        let bob = SKAction.sequence([.moveBy(x: 0, y: 3 * camScale, duration: 0.3), .moveBy(x: 0, y: -3 * camScale, duration: 0.3)])
        body.run(.repeatForever(bob))
        node.addChild(body)
        return node
    }

    func spawnFloat(_ x: Double, _ y: Double, _ text: String, _ color: UIColor, big: Bool = false) {
        let size = (big ? 24 : 18) * camScale
        let label = SKLabelNode(fontNamed: nil)
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: roundedFont(size, .black),
            .foregroundColor: color,
            .strokeColor: inkColor,
            .strokeWidth: -5.0,
        ])
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = sp(x, y)
        label.zPosition = 8
        world.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 1.6 * U, duration: 1),
                    .sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.5)])]),
            .removeFromParent(),
        ]))
    }

    func setupClippings() {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 4)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 4))
        }
        clippings.particleTexture = SKTexture(image: img)
        clippings.particleBirthRate = 0
        clippings.particleLifetime = 0.5
        clippings.particleLifetimeRange = 0.35
        clippings.particleSpeed = 5 * U
        clippings.particleSpeedRange = 4 * U
        clippings.emissionAngle = -.pi / 2
        clippings.emissionAngleRange = 0.9
        clippings.particleAlphaSpeed = -1.6
        clippings.particleScale = 0.28 * U / 8
        clippings.particleScaleRange = 0.12 * U / 8
        clippings.particleRotationRange = .pi * 2
        clippings.particleRotationSpeed = 8
        clippings.particleColor = UIColor(hex: 0x6fbf45)
        clippings.particleColorBlendFactor = 1
        clippings.particleColorGreenRange = 0.25
        clippings.particleColorRedRange = 0.15
        clippings.xAcceleration = 0
        clippings.yAcceleration = 0
    }

    func confetti() {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 5)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 5))
        }
        let e = SKEmitterNode()
        e.particleTexture = SKTexture(image: img)
        e.numParticlesToEmit = 140
        e.particleBirthRate = 1400
        e.particleLifetime = 2.2
        e.particleLifetimeRange = 0.8
        e.particleSpeed = 520
        e.particleSpeedRange = 260
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 1.3
        e.yAcceleration = -900
        e.particleRotationRange = .pi * 2
        e.particleRotationSpeed = 10
        e.particleColor = UIColor(hex: 0xffc92e)
        e.particleColorBlendFactor = 1
        e.particleColorRedRange = 0.6
        e.particleColorGreenRange = 0.8
        e.particleColorBlueRange = 1
        e.particleScale = 1.1
        e.particleScaleRange = 0.5
        e.position = CGPoint(x: 0, y: size.height * 0.15)
        e.zPosition = 30
        cam.addChild(e)
        e.run(.sequence([.wait(forDuration: 3.5), .removeFromParent()]))
    }
}
