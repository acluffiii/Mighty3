import SpriteKit
import UIKit

struct MowerState {
    var x = 0.0, y = 0.0   // cells, y grows downward (same as the web version)
    var a = 0.0            // heading in radians, 0 = facing right
    var v = 0.0            // ft/s
}

final class PowerItem {
    let x: Double
    let y: Double
    let kind: PowerKind
    var life = 16.0
    let node: SKNode

    init(x: Double, y: Double, kind: PowerKind, node: SKNode) {
        self.x = x; self.y = y; self.kind = kind; self.node = node
    }
}

final class JobState {
    var time = 0.0
    var par = 0.0
    var earn = 0.0
    var penalty = 0.0
    var wrecked = 0
    var charge = 0
    var comboT = 0.0
    var mult = 1
    var popAcc = 0.0
    var popT = 0.0
    var items: [PowerItem] = []
    var powerT = 7.0
    var active: [PowerKind: Double] = [:]
    var huntT = 0.0
    var hunt: (x: Double, y: Double)?
    var remain: [Int] = []
    var finishT = 0.0
    var flowerT = 0.0

    func isActive(_ k: PowerKind) -> Bool { (active[k] ?? 0) > 0 }
}

/// The whole game world. Simulation runs in lawn cells with y pointing down, exactly like the web
/// version; `sp(_:_:)` converts to SpriteKit points (U points per cell, y pointing up).
final class GameScene: SKScene {
    weak var session: GameSession?

    let U: CGFloat = 16
    private(set) var lawn: Lawn = LawnGenerator.make(level: 1, demo: true)
    let world = SKNode()
    let cam = SKCameraNode()
    lazy var tiles = LawnTiles(unit: U)
    var tileMap: SKTileMapNode?

    var m = MowerState()
    var job: JobState?
    var mowerNode = SKNode()
    let clippings = SKEmitterNode()
    var wideRing = SKShapeNode()
    var goldNodes: [Int: SKNode] = [:]
    var gnomeNodes: [Int: SKNode] = [:]
    var canopies: [(solid: Solid, node: SKNode)] = []
    let remainNode = SKShapeNode()
    let arrow = SKShapeNode()

    // Touch joystick (children of the camera, sized in screen points)
    let joyBase = SKShapeNode(circleOfRadius: 60)
    let joyKnob = SKShapeNode(circleOfRadius: 23)
    weak var activeTouch: UITouch?
    var touchOrigin: CGPoint?
    var inputVec = CGVector.zero

    var demoWp: [(x: Double, y: Double)] = []
    var demoI = 0

    var ppc: CGFloat = 20          // screen points per cell
    var camX = 0.0, camY = 0.0
    var shakeT = 0.0, bonkCD = 0.0, T = 0.0
    var lastTime: TimeInterval = 0
    var hudT = 0.0, miniT = 0.0
    var lastFresh = 0
    let minimap = MinimapRenderer()

    var camScale: CGFloat { U / ppc }
    var stats: Stats { (session?.save ?? SaveData()).stats }

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(hex: 0x1b3a16)
        addChild(world)
        addChild(cam)
        camera = cam
        setupJoystick()
        setupClippings()
        remainNode.zPosition = 1.5
        remainNode.fillColor = .clear
        remainNode.strokeColor = .white
        remainNode.lineWidth = U * 0.1
        arrow.zPosition = 7
        arrow.fillColor = .white
        arrow.strokeColor = UIColor(hex: 0x15291a)
        updateZoom()
        resetDemo()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateZoom()
    }

    private func updateZoom() {
        guard size.width > 0, size.height > 0 else { return }
        ppc = min(30, max(14, min(size.width, size.height) / 19))
        cam.setScale(camScale)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 14, y: 0))
        path.addLine(to: CGPoint(x: -8, y: 11))
        path.addLine(to: CGPoint(x: -3, y: 0))
        path.addLine(to: CGPoint(x: -8, y: -11))
        path.closeSubpath()
        arrow.path = path
        arrow.lineWidth = 3
        arrow.setScale(camScale)
    }

    // MARK: - Touch (joystick logic lives in Joystick.swift)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { handleTouchesBegan(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { handleTouchesMoved(touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { handleTouchesEnded(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { handleTouchesEnded(touches) }

    // MARK: - Coordinates

    /// Lawn cell coordinates (y down) to scene points (y up).
    func sp(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: CGFloat(x) * U, y: CGFloat(Double(lawn.H) - y) * U)
    }

    /// Lawn rect (top-left origin, y down) to a scene rect.
    func jr(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
        CGRect(x: CGFloat(x) * U, y: CGFloat(Double(lawn.H) - y - h) * U, width: CGFloat(w) * U, height: CGFloat(h) * U)
    }

    // MARK: - Building the world

    func buildWorld() {
        world.removeAllChildren()
        goldNodes = [:]
        gnomeNodes = [:]
        canopies = []

        let hedge = makeHedge()
        hedge.zPosition = -1
        world.addChild(hedge)

        let map = SKTileMapNode(tileSet: tiles.tileSet, columns: lawn.W, rows: lawn.H,
                                tileSize: CGSize(width: U, height: U))
        map.anchorPoint = .zero
        map.position = .zero
        map.zPosition = 0
        for i in 0..<lawn.grid.count { setTile(i, on: map) }
        world.addChild(map)
        tileMap = map

        for i in lawn.gold {
            let n = makeDandelion(i)
            n.zPosition = 1
            world.addChild(n)
            goldNodes[i] = n
        }
        for (idx, s) in lawn.solids.enumerated() {
            let n = makeSolidNode(s)
            n.zPosition = 2
            world.addChild(n)
            if s.kind == .gnome { gnomeNodes[idx] = n }
            if s.kind == .tree {
                let c = makeCanopy(s)
                c.zPosition = 6
                world.addChild(c)
                canopies.append((solid: s, node: c))
            }
        }
        remainNode.path = nil
        world.addChild(remainNode)
        arrow.isHidden = true
        world.addChild(arrow)
        refreshMower()
        minimap.reset(lawn)
    }

    func setTile(_ i: Int, on map: SKTileMapNode? = nil) {
        guard let map = map ?? tileMap else { return }
        map.setTileGroup(tiles.group(for: lawn, index: i), forColumn: i % lawn.W, row: lawn.H - 1 - i / lawn.W)
    }

    func refreshMower() {
        mowerNode.removeFromParent()
        clippings.removeFromParent()
        let st = stats
        mowerNode = makeMower(st)
        mowerNode.zPosition = 4
        clippings.position = CGPoint(x: 0, y: -CGFloat(st.deck * 0.9) * U)
        clippings.zPosition = -0.5
        mowerNode.addChild(clippings)
        clippings.targetNode = world
        wideRing = SKShapeNode(circleOfRadius: CGFloat(st.deck * 1.5) * U)
        wideRing.strokeColor = UIColor(hex: 0x9a55e8, alpha: 0.6)
        wideRing.fillColor = .clear
        wideRing.lineWidth = U * 0.12
        wideRing.isHidden = true
        mowerNode.addChild(wideRing)
        world.addChild(mowerNode)
        syncMower()
    }

    func syncMower() {
        mowerNode.position = sp(m.x, m.y)
        mowerNode.zRotation = CGFloat(-m.a)
    }

    // MARK: - Demo (title screen autopilot)

    func resetDemo() {
        lawn = LawnGenerator.make(level: 1, demo: true)
        job = nil
        buildWorld()
        let d = stats.deck, step = d * 1.7
        demoWp = []
        var dir = 1.0
        var y = Double(lawn.H) - 3 - d * 0.6
        while y > 8 + d {
            let left = 1.5, right = Double(lawn.W) - 1.5
            demoWp.append((x: dir > 0 ? left : right, y: y))
            demoWp.append((x: dir > 0 ? right : left, y: y))
            dir = -dir
            y -= step
        }
        demoI = 0
        m = MowerState(x: 1.5, y: Double(lawn.H) - 3 - d * 0.6, a: 0, v: 0)
        camX = Double(lawn.W) / 2
        camY = Double(lawn.H) / 2
        syncMower()
    }

    private func updateDemo(_ dt: Double) {
        guard demoI < demoWp.count else { resetDemo(); return }
        let st = stats
        let wp = demoWp[demoI]
        let dx = wp.x - m.x, dy = wp.y - m.y, d = hypot(dx, dy)
        if d < 0.8 { demoI += 1 }
        drive(dt, dx / max(d, 1), dy / max(d, 1), st)
        lastFresh = cutAt(st).fresh
    }

    // MARK: - Jobs

    func startJob(level: Int) {
        lawn = LawnGenerator.make(level: level, demo: false)
        job = nil
        buildWorld()
        let st = stats
        m = MowerState(x: lawn.start.x, y: lawn.start.y, a: 0, v: 0)
        let j = JobState()
        j.par = (Double(lawn.total) / (st.speed * st.deck * 2 * 0.6)).rounded() + 10
        job = j
        syncMower()
        camX = m.x
        camY = m.y
        clampCam()
        hudT = 0
        miniT = 0
        session?.showBanner("Job #\(level)", "\(lawn.name) · \(grouped(lawn.total)) sq ft · par \(clock(j.par))")
    }

    /// Returns the net earnings so far, which the player keeps when quitting.
    func quitJob() -> Double {
        guard let j = job else { return 0 }
        job = nil
        return max(0, j.earn - j.penalty)
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(0.05, currentTime - lastTime)
        lastTime = currentTime
        guard let s = session else { return }
        let mode = s.mode

        switch mode {
        case .play:
            updatePlay(dt)
        case .finishing:
            m.v *= 0.9
            lastFresh = 0
            s.sound.setEngine(on: false, speedFraction: 0, cutting: false)
            if let j = job {
                j.finishT -= dt
                if j.finishT <= 0 { showDone() }
            }
        case .title, .shop:
            if lawn.demo { updateDemo(dt) }
            s.sound.setEngine(on: false, speedFraction: 0, cutting: false)
        case .pause, .done:
            lastFresh = 0
            s.sound.setEngine(on: false, speedFraction: 0, cutting: false)
        }

        if mode != .pause {
            T += dt
            shakeT -= dt
            updateCamera(dt)
        }
        syncMower()
        clippings.particleBirthRate = lastFresh > 0 && mode != .pause ? 70 : 0
        wideRing.isHidden = !(job?.isActive(.wide) ?? false)

        for c in canopies {
            let near = hypot(m.x - c.solid.x, m.y - c.solid.y) < c.solid.canopy + 0.5
            c.node.alpha = near ? 0.55 : 1
        }
        if let j = job {
            for it in j.items {
                it.node.alpha = it.life < 3 ? (sin(T * 20) > 0 ? 1 : 0.4) : 1
            }
            remainNode.alpha = CGFloat(0.35 + sin(T * 6) * 0.25)
            updateArrow(j, visible: mode == .play)
        } else {
            arrow.isHidden = true
        }

        hudT -= dt
        if hudT <= 0 {
            hudT = 1.0 / 15
            publishHUD()
        }
        miniT -= dt
        if miniT <= 0, job != nil, minimap.dirty {
            miniT = 0.25
            s.minimap = minimap.image()
        }
    }

    private func updateArrow(_ j: JobState, visible: Bool) {
        guard visible, let target = j.hunt else { arrow.isHidden = true; return }
        let dx = target.x - m.x, dy = target.y - m.y, d = hypot(dx, dy)
        guard d > 4 else { arrow.isHidden = true; return }
        arrow.isHidden = false
        arrow.position = sp(m.x + dx / d * 3, m.y + dy / d * 3)
        arrow.zRotation = CGFloat(-atan2(dy, dx))
        arrow.setScale(camScale * CGFloat(1 + sin(T * 8) * 0.15))
    }

    private func publishHUD() {
        guard let s = session, let j = job else { return }
        var h = HUDState()
        h.cash = Int(s.save.cash + max(0, j.earn - j.penalty))
        h.pct = min(100, Int(lawn.progress * 100))
        h.time = Int(j.time)
        h.par = Int(j.par)
        h.jobName = "Job #\(lawn.level) · \(lawn.name)"
        h.combo = j.mult
        let thr = max(1, Int((50 * stats.deck).rounded()))
        h.showMeter = j.mult > 1 || j.charge > 0
        let fill = j.mult >= 5 ? j.comboT : Double(j.charge % thr) / Double(thr)
        h.comboFill = (min(max(fill, 0), 1) * 50).rounded() / 50
        h.powers = PowerKind.allCases.compactMap { k in
            let r = j.active[k] ?? 0
            return r > 0 ? PowerChip(kind: k, seconds: Int(ceil(r))) : nil
        }
        h.mowerDot = CGPoint(x: m.x / Double(lawn.W), y: m.y / Double(lawn.H))
        if h != s.hud { s.hud = h }
    }

    // MARK: - Simulation

    private func effStats() -> Stats {
        var st = stats
        if let j = job {
            if j.isActive(.turbo) { st.speed *= 1.5 }
            if j.isActive(.wide) { st.deck *= 1.5 }
        }
        return st
    }

    private func angDiff(_ a: Double, _ b: Double) -> Double {
        var d = a - b
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d
    }

    private func drive(_ dt: Double, _ ix: Double, _ iy: Double, _ st: Stats) {
        let mag = min(1, hypot(ix, iy))
        if mag > 0.12 {
            let ta = atan2(iy, ix), da = angDiff(ta, m.a), tr = st.turn * dt
            m.a += min(max(da, -tr), tr)
            let align = max(0, cos(da))
            let target = st.speed * mag * (0.3 + 0.7 * align)
            m.v += (target - m.v) * min(1, dt * 4)
        } else {
            m.v += (0 - m.v) * min(1, dt * 6)
        }
        m.x += cos(m.a) * m.v * dt
        m.y += sin(m.a) * m.v * dt
        collide(st)
    }

    private func collide(_ st: Stats) {
        let br = st.body
        var hit: SolidKind?
        var hitEdge = false
        if m.x < br { m.x = br; hitEdge = true }
        if m.x > Double(lawn.W) - br { m.x = Double(lawn.W) - br; hitEdge = true }
        if m.y < br { m.y = br; hitEdge = true }
        if m.y > Double(lawn.H) - br { m.y = Double(lawn.H) - br; hitEdge = true }

        for (idx, s) in lawn.solids.enumerated() {
            if !s.isRect {
                let dx = m.x - s.x, dy = m.y - s.y, d = hypot(dx, dy), minD = br + s.r
                if d < minD && d > 1e-4 {
                    m.x = s.x + dx / d * minD
                    m.y = s.y + dy / d * minD
                    hit = s.kind
                    if s.kind == .gnome && m.v > 1.5 { wobble(gnomeNodes[idx]) }
                }
            } else {
                let cx = min(max(m.x, s.x), s.x + s.w), cy = min(max(m.y, s.y), s.y + s.h)
                let dx = m.x - cx, dy = m.y - cy, d = hypot(dx, dy)
                if d < br {
                    if d > 1e-4 {
                        m.x = cx + dx / d * br
                        m.y = cy + dy / d * br
                    } else {
                        let pl = m.x - s.x, pr = s.x + s.w - m.x, pt = m.y - s.y, pb = s.y + s.h - m.y
                        let mn = min(pl, pr, pt, pb)
                        if mn == pl { m.x = s.x - br }
                        else if mn == pr { m.x = s.x + s.w + br }
                        else if mn == pt { m.y = s.y - br }
                        else { m.y = s.y + s.h + br }
                    }
                    hit = s.kind
                }
            }
        }

        if (hit != nil || hitEdge) && m.v > 2.4 && bonkCD <= 0 && session?.mode == .play {
            session?.sound.play(.bonk)
            session?.haptics.bump()
            shakeT = 0.22
            bonkCD = 0.6
            m.v *= 0.35
            if hit == .gnome { spawnFloat(m.x, m.y - 1, "Bonk!", .white) }
        }
    }

    private func shadeFor(_ a: Double) -> UInt8 {
        let c = cos(a), s = sin(a)
        if abs(c) >= abs(s) { return c >= 0 ? 1 : 2 }
        return s >= 0 ? 3 : 4
    }

    private func cutAt(_ st: Stats) -> (fresh: Int, wrecked: Int, golds: Int) {
        let d = st.deck, d2 = d * d, shade = shadeFor(m.a)
        let x0 = max(0, Int(floor(m.x - d))), x1 = min(lawn.W - 1, Int(floor(m.x + d)))
        let y0 = max(0, Int(floor(m.y - d))), y1 = min(lawn.H - 1, Int(floor(m.y + d)))
        guard x0 <= x1, y0 <= y1 else { return (0, 0, 0) }
        var fresh = 0, wrecked = 0, golds = 0
        for j in y0...y1 {
            for i in x0...x1 {
                let dx = Double(i) + 0.5 - m.x, dy = Double(j) + 0.5 - m.y
                if dx * dx + dy * dy > d2 { continue }
                let idx = j * lawn.W + i
                let g = lawn.grid[idx]
                if g == Cell.grass {
                    if lawn.cut[idx] == 0 {
                        lawn.cut[idx] = shade
                        lawn.cutCount += 1
                        fresh += 1
                        cellChanged(idx)
                        if lawn.gold.contains(idx) {
                            lawn.gold.remove(idx)
                            goldNodes[idx]?.removeFromParent()
                            goldNodes[idx] = nil
                            golds += 1
                        }
                    } else if lawn.cut[idx] != shade && m.v > 1 {
                        lawn.cut[idx] = shade   // re-striping: the last pass sets the direction
                        cellChanged(idx)
                    }
                } else if g == Cell.flower && !lawn.demo {
                    lawn.grid[idx] = Cell.wreck
                    cellChanged(idx)
                    wrecked += 1
                }
            }
        }
        return (fresh, wrecked, golds)
    }

    private func cellChanged(_ idx: Int) {
        setTile(idx)
        minimap.set(idx, lawn)
    }

    private func updatePlay(_ dt: Double) {
        guard let j = job, let s = session else { return }
        j.time += dt
        let st = effStats()
        drive(dt, Double(inputVec.dx), Double(inputVec.dy), st)
        let res = cutAt(st)
        lastFresh = res.fresh

        let perSqFt = 0.8 * (1 + 0.08 * Double(lawn.level - 1)) * st.pay * (j.isActive(.cash) ? 2 : 1)
        if res.fresh > 0 {
            let gain = Double(res.fresh) * perSqFt * Double(j.mult)
            j.earn += gain
            j.popAcc += gain
            j.comboT = 1.0
            j.charge += res.fresh
            let thr = max(1, Int((50 * stats.deck).rounded()))
            let nm = min(5, 1 + j.charge / thr)
            if nm > j.mult {
                j.mult = nm
                s.sound.play(.combo(nm))
                s.haptics.combo()
            }
        } else if j.comboT > 0 {
            j.comboT -= dt
            if j.comboT <= 0 {
                if j.mult > 1 { spawnFloat(m.x, m.y - 1.5, "Combo lost", .white) }
                j.mult = 1
                j.charge = 0
            }
        }
        j.popT -= dt
        if j.popT <= 0 && j.popAcc >= 1 {
            spawnFloat(m.x, m.y - 1.2, "+" + money(j.popAcc), .white)
            j.popAcc -= floor(j.popAcc)
            j.popT = 0.35
        }
        if res.golds > 0 {
            let g = Double(res.golds) * (20 + 5 * Double(lawn.level)) * st.pay
            j.earn += g
            spawnFloat(m.x, m.y - 2, "+" + money(g) + " dandelion", UIColor(hex: 0xffc92e), big: true)
            s.sound.play(.coin)
            s.haptics.coin()
        }
        if res.wrecked > 0 {
            j.wrecked += res.wrecked
            j.penalty += Double(res.wrecked) * 40
            j.mult = 1
            j.charge = 0
            j.comboT = 0
            if j.flowerT <= 0 {
                spawnFloat(m.x, m.y - 1.5, "The petunias!", UIColor(hex: 0xff8a7a), big: true)
                s.sound.play(.flower)
                s.haptics.flower()
                shakeT = 0.15
                j.flowerT = 0.8
            }
        }
        j.flowerT -= dt
        bonkCD -= dt
        for k in Array(j.active.keys) { j.active[k] = (j.active[k] ?? 0) - dt }

        // Power-ups
        let prog = lawn.progress
        j.powerT -= dt
        if j.powerT <= 0 && prog < 0.88 {
            spawnItem(j)
            j.powerT = 11 + lawn.rng.next() * 8
        }
        for it in j.items {
            it.life -= dt
            if hypot(it.x - m.x, it.y - m.y) < st.body + 0.7 {
                it.life = -1
                j.active[it.kind] = it.kind.duration
                s.sound.play(.power)
                s.haptics.power()
                spawnFloat(it.x, it.y - 1, it.kind.label + "!", .white, big: true)
            }
            if it.life <= 0 { it.node.removeFromParent() }
        }
        j.items.removeAll { $0.life <= 0 }

        // Point the way to the last patches
        j.huntT -= dt
        if prog > 0.85 && j.huntT <= 0 {
            j.huntT = 0.3
            var best: (x: Double, y: Double)?
            var bd = Double.greatestFiniteMagnitude
            j.remain = []
            for i in 0..<lawn.grid.count where lawn.grid[i] == Cell.grass && lawn.cut[i] == 0 {
                let x = Double(i % lawn.W) + 0.5, y = Double(i / lawn.W) + 0.5
                let dd = (x - m.x) * (x - m.x) + (y - m.y) * (y - m.y)
                if dd < bd { bd = dd; best = (x: x, y: y) }
                if j.remain.count < 400 { j.remain.append(i) }
            }
            j.hunt = best
            if prog > 0.93 {
                let path = CGMutablePath()
                for i in j.remain {
                    path.addRect(jr(Double(i % lawn.W) + 0.1, Double(i / lawn.W) + 0.1, 0.8, 0.8))
                }
                remainNode.path = path
            }
        }

        let left = lawn.total - lawn.cutCount
        if left <= max(3, lawn.total / 250) { finishJob() }
        s.sound.setEngine(on: true, speedFraction: m.v / max(st.speed, 0.1), cutting: res.fresh > 0)
    }

    private func spawnItem(_ j: JobState) {
        for _ in 0..<50 {
            let i = Int(lawn.rng.next() * Double(lawn.grid.count))
            guard i < lawn.grid.count, lawn.grid[i] == Cell.grass, lawn.cut[i] == 0 else { continue }
            let x = Double(i % lawn.W) + 0.5, y = Double(i / lawn.W) + 0.5
            if hypot(x - m.x, y - m.y) < 6 { continue }
            let kinds = PowerKind.allCases
            let kind = kinds[Int(lawn.rng.next() * Double(kinds.count)) % kinds.count]
            let node = makePowerItem(kind)
            node.position = sp(x, y)
            node.zPosition = 5
            world.addChild(node)
            j.items.append(PowerItem(x: x, y: y, kind: kind, node: node))
            return
        }
    }

    private func finishJob() {
        guard let s = session, let j = job else { return }
        s.mode = .finishing
        j.finishT = 1.8
        remainNode.path = nil
        s.sound.play(.win)
        s.haptics.win()
        confetti()
        s.showBanner("Lawn complete!", "Nice stripes")
    }

    private func stripeScore() -> Double {
        var pairs = 0, same = 0
        for jj in 0..<lawn.H {
            for i in 0..<lawn.W {
                let idx = jj * lawn.W + i, s = lawn.cut[idx]
                if s == 0 || lawn.grid[idx] != Cell.grass { continue }
                let n: Int
                if s <= 2 { n = i + 1 < lawn.W ? idx + 1 : -1 } else { n = jj + 1 < lawn.H ? idx + lawn.W : -1 }
                if n < 0 || lawn.grid[n] != Cell.grass || lawn.cut[n] == 0 { continue }
                pairs += 1
                if lawn.cut[n] == s { same += 1 }
            }
        }
        return pairs > 0 ? Double(same) / Double(pairs) : 0
    }

    private func showDone() {
        guard let s = session, let j = job else { return }
        let st = stats, lvl = lawn.level
        let stripe = stripeScore()
        let allowFlowers = max(1, lawn.flowers / 20)
        let checks = [
            JobCheck(label: "Beat par time", value: "\(clock(j.time)) / \(clock(j.par))", ok: j.time <= j.par),
            JobCheck(label: "Flower beds intact", value: j.wrecked > 0 ? "\(j.wrecked) lost" : "none lost", ok: j.wrecked <= allowFlowers),
            JobCheck(label: "Straight stripes", value: "\(Int((stripe * 100).rounded()))%", ok: stripe >= 0.7),
        ]
        let stars = checks.filter { $0.ok }.count
        let fee = 200 + 60 * Double(lvl)
        let tip = Double(stars) * (80 + 30 * Double(lvl)) * st.pay
        let result = JobResult(level: lvl, lawnName: lawn.name, sqft: lawn.total, stars: stars, checks: checks,
                               earn: j.earn, fee: fee, tip: tip, penalty: j.penalty)
        for it in j.items { it.node.removeFromParent() }
        j.items = []
        j.hunt = nil
        s.complete(result)
    }

    // MARK: - Camera

    func clampCam() {
        let vw = Double(size.width / ppc), vh = Double(size.height / ppc)
        let W = Double(lawn.W), H = Double(lawn.H)
        camX = W + 3 <= vw ? W / 2 : min(max(camX, vw / 2 - 1.5), W + 1.5 - vw / 2)
        camY = H + 3 <= vh ? H / 2 : min(max(camY, vh / 2 - 3), H + 1.5 - vh / 2)
    }

    private func updateCamera(_ dt: Double) {
        let lead = 0.45
        let tx = m.x + cos(m.a) * m.v * lead, ty = m.y + sin(m.a) * m.v * lead
        let k = min(1, dt * 4)
        camX += (tx - camX) * k
        camY += (ty - camY) * k
        clampCam()
        var sx = 0.0, sy = 0.0
        if shakeT > 0 {
            sx = Double.random(in: -4...4) / Double(ppc)
            sy = Double.random(in: -4...4) / Double(ppc)
        }
        cam.position = sp(camX + sx, camY + sy)
    }
}
