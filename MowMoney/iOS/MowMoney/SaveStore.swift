import Foundation

/// Everything that persists between launches.
struct SaveData: Codable, Equatable {
    var cash: Double = 0
    var level = 1
    var speed = 0
    var deck = 0
    var tip = 0
    var tier = 0
    var owned: [Int] = [0]
    var best: [String: Int] = [:]   // job level -> best stars
    var sqft = 0
    var muted = false
    var handedness: String?          // "left" or "right"; nil until the player picks

    init() {}

    // Tolerates missing keys so adding fields later never wipes a save.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cash = try c.decodeIfPresent(Double.self, forKey: .cash) ?? 0
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? 1
        speed = try c.decodeIfPresent(Int.self, forKey: .speed) ?? 0
        deck = try c.decodeIfPresent(Int.self, forKey: .deck) ?? 0
        tip = try c.decodeIfPresent(Int.self, forKey: .tip) ?? 0
        tier = try c.decodeIfPresent(Int.self, forKey: .tier) ?? 0
        owned = try c.decodeIfPresent([Int].self, forKey: .owned) ?? [0]
        best = try c.decodeIfPresent([String: Int].self, forKey: .best) ?? [:]
        sqft = try c.decodeIfPresent(Int.self, forKey: .sqft) ?? 0
        muted = try c.decodeIfPresent(Bool.self, forKey: .muted) ?? false
        handedness = try c.decodeIfPresent(String.self, forKey: .handedness)
    }

    func level(of id: UpgradeID) -> Int {
        switch id {
        case .speed: return speed
        case .deck: return deck
        case .tip: return tip
        }
    }

    mutating func bump(_ id: UpgradeID) {
        switch id {
        case .speed: speed += 1
        case .deck: deck += 1
        case .tip: tip += 1
        }
    }

    func cost(of id: UpgradeID) -> Double {
        guard let u = Catalog.upgrades.first(where: { $0.id == id }) else { return 0 }
        return (u.base * pow(1.6, Double(level(of: id))) / 10).rounded() * 10
    }

    var stats: Stats {
        let t = Catalog.tiers[min(max(tier, 0), Catalog.tiers.count - 1)]
        return Stats(deck: t.deck * (1 + 0.08 * Double(deck)),
                     speed: t.speed * (1 + 0.08 * Double(speed)),
                     turn: t.turn,
                     body: t.body,
                     pay: 1 + 0.1 * Double(tip))
    }
}

enum SaveStore {
    private static let key = "mowmoney.v1"

    static func load() -> SaveData {
        guard let data = UserDefaults.standard.data(forKey: key),
              let save = try? JSONDecoder().decode(SaveData.self, from: data) else { return SaveData() }
        return save
    }

    static func store(_ save: SaveData) {
        if let data = try? JSONEncoder().encode(save) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
