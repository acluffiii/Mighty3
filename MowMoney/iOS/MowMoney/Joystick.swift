import SpriteKit
import UIKit

// MARK: - Floating touch joystick

extension GameScene {
    private var stickRadius: CGFloat { 50 }

    func setupJoystick() {
        joyBase.fillColor = UIColor(red: 10 / 255, green: 25 / 255, blue: 8 / 255, alpha: 0.18)
        joyBase.strokeColor = UIColor(white: 1, alpha: 0.55)
        joyBase.lineWidth = 3
        joyBase.zPosition = 20
        joyBase.isHidden = true
        joyKnob.fillColor = UIColor(white: 1, alpha: 0.85)
        joyKnob.strokeColor = inkColor
        joyKnob.lineWidth = 3
        joyKnob.zPosition = 21
        joyKnob.isHidden = true
        cam.addChild(joyBase)
        cam.addChild(joyKnob)
    }

    /// View point (y down, origin top-left) to camera-local point. Children of the camera are drawn in screen points.
    private func camPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - size.width / 2, y: size.height / 2 - p.y)
    }

    func handleTouchesBegan(_ touches: Set<UITouch>) {
        guard session?.mode == .play, activeTouch == nil, let t = touches.first, let v = view else { return }
        activeTouch = t
        let p = t.location(in: v)
        touchOrigin = p
        inputVec = .zero
        joyBase.position = camPoint(p)
        joyKnob.position = camPoint(p)
        joyBase.isHidden = false
        joyKnob.isHidden = false
    }

    func handleTouchesMoved(_ touches: Set<UITouch>) {
        guard let t = activeTouch, touches.contains(t), var o = touchOrigin, let v = view else { return }
        let p = t.location(in: v)
        var dx = p.x - o.x, dy = p.y - o.y
        let d = hypot(dx, dy), R = stickRadius
        if d > R {
            // Drag the stick along with the finger so you never run out of room.
            o.x += dx * (1 - R / d)
            o.y += dy * (1 - R / d)
            touchOrigin = o
            dx = p.x - o.x
            dy = p.y - o.y
            joyBase.position = camPoint(o)
        }
        inputVec = CGVector(dx: dx / R, dy: dy / R)   // y down, same as the simulation
        joyKnob.position = camPoint(p)
    }

    func handleTouchesEnded(_ touches: Set<UITouch>) {
        if let t = activeTouch, touches.contains(t) { cancelInput() }
    }

    func cancelInput() {
        activeTouch = nil
        touchOrigin = nil
        inputVec = .zero
        joyBase.isHidden = true
        joyKnob.isHidden = true
    }
}

// MARK: - Minimap

/// One pixel per lawn cell. Cells are updated as they change; SwiftUI shows a snapshot a few times a second.
final class MinimapRenderer {
    private var ctx: CGContext?
    private var W = 0
    private var H = 0
    private(set) var dirty = false

    func reset(_ lawn: Lawn) {
        W = lawn.W
        H = lawn.H
        ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.interpolationQuality = .none
        for i in 0..<lawn.grid.count { set(i, lawn) }
        dirty = true
    }

    func set(_ i: Int, _ lawn: Lawn) {
        guard let c = ctx else { return }
        c.setFillColor(LawnTiles.minimapColor(for: lawn, index: i))
        // Bitmap contexts put y = 0 at the bottom, lawn row 0 is the top.
        c.fill(CGRect(x: i % W, y: H - 1 - i / W, width: 1, height: 1))
        dirty = true
    }

    func image() -> CGImage? {
        dirty = false
        return ctx?.makeImage()
    }
}
