import SpriteKit
import UIKit

// MARK: - Corner joystick (bottom right for right-handed players, bottom left for left-handed)

extension GameScene {
    private var stickRadius: CGFloat { 50 }

    private var isRightHanded: Bool { session?.isRightHanded ?? true }

    /// Resting center of the stick in view coordinates (y down), clear of the home bar.
    var stickCenter: CGPoint {
        CGPoint(x: isRightHanded ? size.width - 100 : 100, y: size.height - 150)
    }

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

    /// Puts the stick back in its corner. Called on size changes and when handedness changes.
    func layoutJoystick() {
        guard size.width > 0, size.height > 0 else { return }
        joyBase.position = camPoint(stickCenter)
        if activeTouch == nil { joyKnob.position = joyBase.position }
    }

    /// Shows the resting stick only while a job is running.
    func updateJoystickVisibility(_ mode: GameMode) {
        let visible = mode == .play || mode == .finishing
        joyBase.isHidden = !visible
        joyKnob.isHidden = !visible
        let alpha: CGFloat = activeTouch == nil ? 0.55 : 1
        joyBase.alpha = alpha
        joyKnob.alpha = alpha
    }

    /// View point (y down, origin top-left) to camera-local point. Children of the camera are drawn in screen points.
    private func camPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - size.width / 2, y: size.height / 2 - p.y)
    }

    /// Touches only steer when they start in the stick's corner: that half of the screen, lower 55%.
    private func inStickZone(_ p: CGPoint) -> Bool {
        let rightHalf = p.x >= size.width / 2
        return rightHalf == isRightHanded && p.y >= size.height * 0.45
    }

    func handleTouchesBegan(_ touches: Set<UITouch>) {
        guard session?.mode == .play, activeTouch == nil, let v = view,
              let t = touches.first(where: { inStickZone($0.location(in: v)) }) else { return }
        activeTouch = t
        moveKnob(to: t.location(in: v))
    }

    func handleTouchesMoved(_ touches: Set<UITouch>) {
        guard let t = activeTouch, touches.contains(t), let v = view else { return }
        moveKnob(to: t.location(in: v))
    }

    func handleTouchesEnded(_ touches: Set<UITouch>) {
        if let t = activeTouch, touches.contains(t) { cancelInput() }
    }

    /// The base stays put; the knob follows the finger and stops at the edge of the stick.
    private func moveKnob(to p: CGPoint) {
        let c = stickCenter
        var dx = p.x - c.x, dy = p.y - c.y
        let d = hypot(dx, dy), R = stickRadius
        if d > R {
            dx *= R / d
            dy *= R / d
        }
        inputVec = CGVector(dx: dx / R, dy: dy / R)   // y down, same as the simulation
        joyKnob.position = camPoint(CGPoint(x: c.x + dx, y: c.y + dy))
    }

    func cancelInput() {
        activeTouch = nil
        touchOrigin = nil
        inputVec = .zero
        joyKnob.position = joyBase.position
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
