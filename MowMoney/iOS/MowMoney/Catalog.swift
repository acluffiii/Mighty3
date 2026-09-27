import UIKit

// Game tuning. Numbers match the web version (MowMoney/index.html) so both play the same.
// World units: 1 lawn cell = 1 sq ft. Speeds are ft/s, deck is the cutting radius in ft.

struct MowerTier {
    let name: String
    let price: Double
    let deck: Double
    let speed: Double
    let turn: Double   // radians per second
    let body: Double   // collision radius
    let color: UIColor
    let blurb: String
}

enum UpgradeID: String, Codable, CaseIterable {
    case speed, deck, tip
}

struct Upgrade {
    let id: UpgradeID
    let name: String
    let desc: String
    let base: Double
}

struct Stats {
    var deck: Double
    var speed: Double
    var turn: Double
    var body: Double
    var pay: Double
}

enum PowerKind: String, CaseIterable {
    case turbo, wide, cash

    var label: String {
        switch self {
        case .turbo: return "Turbo"
        case .wide: return "Wide deck"
        case .cash: return "Double pay"
        }
    }
    var color: UIColor {
        switch self {
        case .turbo: return UIColor(hex: 0x1f9be0)
        case .wide: return UIColor(hex: 0x9a55e8)
        case .cash: return UIColor(hex: 0xe0a500)
        }
    }
    var duration: Double {
        switch self {
        case .turbo: return 6
        case .wide, .cash: return 8
        }
    }
    var glyph: String {
        switch self {
        case .turbo: return "»"
        case .wide: return "↔"
        case .cash: return "$"
        }
    }
}

enum Catalog {
    static let tiers: [MowerTier] = [
        MowerTier(name: "Push Mower", price: 0, deck: 1.15, speed: 4.6, turn: 6.5, body: 0.7,
                  color: UIColor(hex: 0xe2412f), blurb: "Pull cord, grass bag, character."),
        MowerTier(name: "Lawn Tractor", price: 6000, deck: 1.55, speed: 6.0, turn: 3.8, body: 0.85,
                  color: UIColor(hex: 0x2f8f3a), blurb: "Cup holder included."),
        MowerTier(name: "Zero-Turn", price: 25000, deck: 1.95, speed: 7.6, turn: 10, body: 0.95,
                  color: UIColor(hex: 0xf08a1c), blurb: "Spins on a dime. Pros only."),
        MowerTier(name: "Mega Deck", price: 90000, deck: 2.6, speed: 8.6, turn: 4.2, body: 1.1,
                  color: UIColor(hex: 0xf2c320), blurb: "Golf course hardware."),
    ]

    static let upgrades: [Upgrade] = [
        Upgrade(id: .speed, name: "Engine tune", desc: "+8% top speed", base: 300),
        Upgrade(id: .deck, name: "Wider blades", desc: "+8% cutting width", base: 380),
        Upgrade(id: .tip, name: "Curb appeal", desc: "+10% pay per sq ft", base: 340),
    ]

    static let upgradeMax = 10
}

// MARK: - Formatting

func mph(_ feetPerSecond: Double) -> String {
    String(format: "%.1f", feetPerSecond * 0.6818)
}

func deckInches(_ radius: Double) -> Int {
    Int((radius * 24).rounded())
}

private let groupedFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    f.locale = Locale(identifier: "en_US")
    return f
}()

func grouped(_ n: Int) -> String {
    groupedFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
}

func money(_ n: Double) -> String {
    "$" + grouped(Int(n.rounded(.down)))
}

func clock(_ seconds: Double) -> String {
    let s = max(0, Int(seconds))
    return "\(s / 60):" + String(format: "%02d", s % 60)
}

// MARK: - Colors

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: alpha)
    }

    /// Positive amounts mix toward white, negative toward black.
    func shaded(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func f(_ v: CGFloat) -> CGFloat { amount >= 0 ? v + (1 - v) * amount : v * (1 + amount) }
        return UIColor(red: f(r), green: f(g), blue: f(b), alpha: a)
    }
}

func roundedFont(_ size: CGFloat, _ weight: UIFont.Weight = .black) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    if let d = base.fontDescriptor.withDesign(.rounded) {
        return UIFont(descriptor: d, size: size)
    }
    return base
}
