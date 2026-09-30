import SwiftUI
import SpriteKit

enum GameMode {
    case title, play, pause, finishing, done, shop
}

struct PowerChip: Equatable, Identifiable {
    let kind: PowerKind
    let seconds: Int
    var id: String { kind.rawValue }
}

/// What the HUD shows. The scene publishes it about 15 times a second.
struct HUDState: Equatable {
    var cash = 0
    var pct = 0
    var time = 0
    var par = 0
    var jobName = ""
    var combo = 1
    var comboFill = 0.0
    var showMeter = false
    var powers: [PowerChip] = []
    var mowerDot = CGPoint.zero      // 0...1 across the lawn
}

struct JobCheck: Identifiable {
    let label: String
    let value: String
    let ok: Bool
    var id: String { label }
}

struct JobResult {
    let level: Int
    let lawnName: String
    let sqft: Int
    let stars: Int
    let checks: [JobCheck]
    let earn: Double
    let fee: Double
    let tip: Double
    let penalty: Double
    var total: Double { max(0, earn + fee + tip - penalty) }
}

struct BannerInfo: Equatable {
    let id = UUID()
    let title: String
    let subtitle: String?
}

/// Owns the save, the scene, audio and haptics, and every action the SwiftUI screens can take.
final class GameSession: ObservableObject {
    @Published var mode: GameMode = .title
    @Published var save: SaveData
    @Published var hud = HUDState()
    @Published var result: JobResult?
    @Published var banner: BannerInfo?
    @Published var minimap: CGImage?

    let scene: GameScene
    let sound = SoundEngine()
    let haptics = Haptics()

    init() {
        let loaded = SaveStore.load()
        save = loaded
        scene = GameScene(size: CGSize(width: 390, height: 844))
        sound.muted = loaded.muted
        scene.session = self
        scene.resetDemo()
    }

    func persist() { SaveStore.store(save) }

    // MARK: - Flow

    func startJob() {
        sound.play(.click)
        minimap = nil
        result = nil
        scene.startJob(level: save.level)
        mode = .play
    }

    func pause() {
        guard mode == .play else { return }
        scene.cancelInput()
        mode = .pause
    }

    func resume() {
        sound.play(.click)
        mode = .play
    }

    func quitJob() {
        save.cash += scene.quitJob()
        persist()
        sound.play(.click)
        mode = .title
        scene.resetDemo()
    }

    func openGarage() {
        sound.play(.click)
        if mode == .done { scene.resetDemo() }
        mode = .shop
    }

    func closeGarage() {
        sound.play(.click)
        mode = .title
    }

    /// Called by the scene when the finish celebration ends.
    func complete(_ r: JobResult) {
        save.cash += r.total
        save.sqft += r.sqft
        save.best[String(r.level)] = max(save.best[String(r.level)] ?? 0, r.stars)
        save.level = r.level + 1
        persist()
        result = r
        mode = .done
    }

    // MARK: - Garage

    func buy(_ id: UpgradeID) {
        let cost = save.cost(of: id)
        guard save.level(of: id) < Catalog.upgradeMax, save.cash >= cost else { return }
        save.cash -= cost
        save.bump(id)
        persist()
        sound.play(.buy)
        haptics.buy()
        scene.refreshMower()
    }

    func selectTier(_ i: Int) {
        let t = Catalog.tiers[i]
        if !save.owned.contains(i) {
            guard save.cash >= t.price else { return }
            save.cash -= t.price
            save.owned.append(i)
        }
        save.tier = i
        persist()
        sound.play(.buy)
        haptics.buy()
        scene.resetDemo()
    }

    // MARK: - Controls

    /// Right-handed until the player says otherwise.
    var isRightHanded: Bool { save.handedness != "left" }

    /// True on first launch, before the player has picked a hand.
    var needsHandedness: Bool { save.handedness == nil }

    func setHandedness(rightHanded: Bool) {
        save.handedness = rightHanded ? "right" : "left"
        persist()
        sound.play(.click)
        haptics.coin()
        scene.cancelInput()
        scene.layoutJoystick()
    }

    func toggleHandedness() {
        setHandedness(rightHanded: !isRightHanded)
    }

    func toggleMute() {
        save.muted.toggle()
        sound.muted = save.muted
        persist()
    }

    func showBanner(_ title: String, _ subtitle: String? = nil) {
        let b = BannerInfo(title: title, subtitle: subtitle)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { banner = b }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { [weak self] in
            guard let self = self, self.banner == b else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.banner = nil }
        }
    }
}
