import SwiftUI
import Combine

/// Posted when the "Start New Estimate" widget is tapped and the deep link
/// (dentdog://newEstimate) is opened. PanelStackView listens for this and
/// resets both decks — see HailDeckApp.swift's onOpenURL for where it's sent.
extension Notification.Name {
    static let startNewEstimate = Notification.Name("dentdog.startNewEstimate")
}

enum DentSize: String, CaseIterable, Identifiable {
    case dime = "Dime"
    case nickel = "Nickel"
    case quarter = "Quarter"
    case half = "Half$"
    var id: String { rawValue }
}

enum Markup: String, CaseIterable, Identifiable {
    case aluminum = "Alum"
    case extended = "Extended"
    case double = "Double"
    case gluePull = "Glue"
    var id: String { rawValue }
}

/// Dent count bracket. Boundaries and the yellow→maroon severity colors match
/// the web build; label stays "201+" for the chip even though the pricing
/// engine below treats it internally as the 201–300 tier.
struct DentBracket: Identifiable, Equatable {
    let id: Int
    let label: String
    let color: Color
    let textColor: Color
}

let dentBrackets: [DentBracket] = [
    DentBracket(id: 0, label: "1–5",     color: Color(hex: "FFD84D"), textColor: Color(hex: "241D00")),
    DentBracket(id: 1, label: "6–15",    color: Color(hex: "FFC53D"), textColor: Color(hex: "241D00")),
    DentBracket(id: 2, label: "16–30",   color: Color(hex: "FFAB2E"), textColor: Color(hex: "241300")),
    DentBracket(id: 3, label: "31–50",   color: Color(hex: "FF8F1F"), textColor: Color(hex: "241300")),
    DentBracket(id: 4, label: "51–75",   color: Color(hex: "FF7315"), textColor: .white),
    DentBracket(id: 5, label: "76–100",  color: Color(hex: "FF5A1A"), textColor: .white),
    DentBracket(id: 6, label: "101–150", color: Color(hex: "F03D1A"), textColor: .white),
    DentBracket(id: 7, label: "151–200", color: Color(hex: "D42323"), textColor: .white),
    DentBracket(id: 8, label: "201+",    color: Color(hex: "A8171A"), textColor: .white),
]

// MARK: - Panels

enum PanelKind {
    case estimate   // full dent-count/size/oversize/markup/price card
    case photo      // required documentation shot — capture only, no dent fields
}

enum PanelClass {
    case standard
    case roof
}

struct PanelSpec: Identifiable {
    let id = UUID()
    let name: String
    let code: String
    var cls: PanelClass = .standard
    var kind: PanelKind = .estimate
}

/// 13 damage-estimate panels + 7 required documentation photos = 20 cards,
/// same composition as the web build.
let panelDeck: [PanelSpec] = [
    PanelSpec(name: "Hood",              code: "HOOD",  cls: .standard),
    PanelSpec(name: "Roof",              code: "ROOF",  cls: .roof),
    PanelSpec(name: "Trunk Lid",         code: "TRNK",  cls: .standard),
    PanelSpec(name: "Front Fender — L",  code: "FF-L",  cls: .standard),
    PanelSpec(name: "Front Fender — R",  code: "FF-R",  cls: .standard),
    PanelSpec(name: "Door — FL",         code: "DR-FL", cls: .standard),
    PanelSpec(name: "Door — FR",         code: "DR-FR", cls: .standard),
    PanelSpec(name: "Door — RL",         code: "DR-RL", cls: .standard),
    PanelSpec(name: "Door — RR",         code: "DR-RR", cls: .standard),
    PanelSpec(name: "Quarter Panel — L", code: "QP-L",  cls: .standard),
    PanelSpec(name: "Quarter Panel — R", code: "QP-R",  cls: .standard),
    PanelSpec(name: "Roof Rail — L",     code: "RR-L",  cls: .standard),
    PanelSpec(name: "Roof Rail — R",     code: "RR-R",  cls: .standard),

    PanelSpec(name: "Front-Left Corner",  code: "FLC", kind: .photo),
    PanelSpec(name: "Front-Right Corner", code: "FRC", kind: .photo),
    PanelSpec(name: "Rear-Left Corner",   code: "RLC", kind: .photo),
    PanelSpec(name: "Rear-Right Corner",  code: "RRC", kind: .photo),
    PanelSpec(name: "VIN",                code: "VIN", kind: .photo),
    PanelSpec(name: "Odometer",           code: "ODO", kind: .photo),
    PanelSpec(name: "License Plate",      code: "PLT", kind: .photo),
]

// MARK: - Pricing engine
// ============================================================
// Exact rule-based reconstruction from the physical rate card —
// not an approximation. See haildeck.html (same underlying DentDOG logic;
// this is a straight port.
//
// STANDARD (every panel except Roof) bracket-to-bracket deltas
// within the Dime column: b-a=50, c-b=50, d-c=50, e-d=50, f-e=50,
// g-f=75, h-g=125. Caps at bracket h (151–200) — standard panels
// have no 201–300 tier.
//
// ROOF's own deltas: b-a=75, c-b=100, d-c=75, e-d=25, f-e=75,
// g-f=75, h-g=150, i-h=275. Roof is the only panel priced through
// 201–300.
//
// Size step (Dime→Nickel→Quarter→Half$) is shared by both
// schedules: 25 at brackets a–e, 75 at f–g, 125 at h and beyond
// (checkpoints given at a, f, h — held constant between them).
//
// VERIFIED OVERRIDES: Hood, Roof, and Trunk Lid ("Deck Lid" on the
// card) have real numbers read off the photo for brackets e–i
// (51–75 through 201–300), superseding the formula. `nil` in an
// override means the card prints "CR" — Conventional Repair or
// panel Replace, beyond PDR feasibility, not a flat price.
// ============================================================

enum PanelPrice: Equatable {
    case value(Int)
    case conventionalRepair          // card says "CR"
    case unavailable                  // fields not selected yet, or bracket doesn't exist for this panel
}

enum Pricing {
    static let seed = 75 // a1 — the one input value the whole matrix is generated from
    static let oversizeSurchargePerDent = 50
    static let markupPercent: [Markup: Double] = [.aluminum: 0.25]

    static let standardBracketOffsets = [0, 50, 100, 150, 200, 250, 325, 450]              // a..h
    static let roofBracketOffsets     = [0, 75, 175, 250, 275, 350, 425, 575, 850]         // a..i

    static func sizeStep(forBracket idx: Int) -> Int {
        if idx <= 4 { return 25 }   // a,b,c,d,e
        if idx <= 6 { return 75 }   // f,g
        return 125                  // h,i
    }

    static func roundUpTo5(_ n: Double) -> Int { Int((n / 5).rounded(.up) * 5) }

    /// [bracketIndex: [DentSize: price]] for one schedule, generated from the seed.
    static func buildSchedule(offsets: [Int]) -> [Int: [DentSize: Int]] {
        var rows: [Int: [DentSize: Int]] = [:]
        for (i, offset) in offsets.enumerated() {
            let dime = Double(seed + offset)
            let step = Double(sizeStep(forBracket: i))
            rows[i] = [
                .dime:    roundUpTo5(dime),
                .nickel:  roundUpTo5(dime + step),
                .quarter: roundUpTo5(dime + step*2),
                .half:    roundUpTo5(dime + step*3),
            ]
        }
        return rows
    }

    static let standardMatrix = buildSchedule(offsets: standardBracketOffsets)
    static let roofMatrix = buildSchedule(offsets: roofBracketOffsets)

    /// nil in the inner dictionary = CR. Missing entries fall back to the formula.
    static let overrides: [String: [Int: [DentSize: Int?]]] = [
        "HOOD": [
            4: [.dime: 325, .nickel: 350, .quarter: 450, .half: 575],
            5: [.dime: 375, .nickel: 450, .quarter: 550, .half: 575],
            6: [.dime: 450, .nickel: 600, .quarter: nil, .half: nil],
            7: [.dime: 450, .nickel: 600, .quarter: nil, .half: nil],
            8: [.dime: 450, .nickel: 600, .quarter: nil, .half: nil],
        ],
        "ROOF": [
            4: [.dime: 425, .nickel: 500, .quarter: 625, .half: 725],
            5: [.dime: 450, .nickel: 525, .quarter: 650, .half: 850],
            6: [.dime: 525, .nickel: 600, .quarter: 700, .half: 950],
            7: [.dime: 575, .nickel: 800, .quarter: 975, .half: 1200],
            8: [.dime: 575, .nickel: 1200, .quarter: 1500, .half: 1800],
        ],
        "TRNK": [ // "Deck Lid" on the physical card
            4: [.dime: 350, .nickel: 400, .quarter: 450, .half: 550],
            5: [.dime: 375, .nickel: 450, .quarter: 575, .half: nil],
            6: [.dime: 450, .nickel: 575, .quarter: nil, .half: nil],
            7: [.dime: 450, .nickel: 575, .quarter: nil, .half: nil],
            8: [.dime: 450, .nickel: 575, .quarter: nil, .half: nil],
        ],
    ]

    /// Base per-dent price before oversize/markup adjustments. Checks verified
    /// overrides first, falls back to the generated formula.
    static func basePrice(panel: PanelSpec, bracketIdx: Int, size: DentSize) -> PanelPrice {
        if let overrideRow = overrides[panel.code]?[bracketIdx] {
            guard let val = overrideRow[size] ?? nil else { return .conventionalRepair }
            return .value(val)
        }
        let matrix = panel.cls == .roof ? roofMatrix : standardMatrix
        guard let row = matrix[bracketIdx], let val = row[size] else { return .unavailable }
        return .value(val)
    }

    /// Full computed price for one card given its current selections.
    static func computePrice(panel: PanelSpec, state: PanelState) -> PanelPrice {
        guard let bracket = state.dentBracket, let size = state.size else { return .unavailable }
        switch basePrice(panel: panel, bracketIdx: bracket.id, size: size) {
        case .conventionalRepair: return .conventionalRepair
        case .unavailable: return .unavailable
        case .value(let base):
            var price = Double(base + state.oversizeCount * oversizeSurchargePerDent)
            for m in state.markups {
                if let pct = markupPercent[m] { price += price * pct }
            }
            return .value(roundUpTo5(price))
        }
    }
}

// MARK: - Per-card mutable state

/// Wraps one vehicle's full 20-card deck so the app can hold two of these
/// and switch between them — mirrors the web build's PanelDeck class.
final class VehicleDeckState: ObservableObject, Identifiable {
    let id = UUID()
    let label: String
    @Published var panels: [PanelState]

    init(label: String) {
        self.label = label
        self.panels = panelDeck.map { PanelState(spec: $0) }
    }

    var savedCount: Int { panels.filter(\.isComplete).count }

    var estimateTotal: Int {
        panels.reduce(0) { sum, p in
            if case .value(let v) = p.price { return sum + v }
            return sum
        }
    }

    /// Clears this vehicle's deck back to a blank state. Used by the
    /// "Start New Estimate" widget deep link — NOT tied to any persistence
    /// layer, since the Swift app doesn't have one yet (unlike the web
    /// build, which got IndexedDB persistence separately). This just
    /// resets in-memory state the same way the constructor does.
    func reset() {
        panels = panelDeck.map { PanelState(spec: $0) }
    }
}

/// Mutable per-panel state. One instance per card in the deck (estimate or doc).
final class PanelState: ObservableObject, Identifiable {
    let id = UUID()
    let spec: PanelSpec

    @Published var dentBracket: DentBracket? = nil
    @Published var oversizeCount: Int = 0
    @Published var size: DentSize? = nil
    @Published var markups: Set<Markup> = []
    @Published var photo: UIImage? = nil

    /// Set when size was determined via LiDAR/marker measurement rather
    /// than manual chip selection — DentMeasurement is defined in
    /// DentSizeMeasurement.swift (DentDOG 2.0). nil means the size (if any)
    /// was picked by hand, same as before this feature existed.
    @Published var lastMeasurement: DentMeasurement? = nil

    /// Fires true exactly once, the moment the card flips from incomplete to complete —
    /// drives the completion pulse animation without re-triggering on every edit.
    @Published var justCompleted: Bool = false

    init(spec: PanelSpec) {
        self.spec = spec
    }

    /// Doc cards (VIN, corners, etc.) are complete the instant a photo exists —
    /// no dent fields to fill in. Estimate panels need bracket + size + photo;
    /// markups are the one genuinely optional field.
    var isComplete: Bool {
        if spec.kind == .photo { return photo != nil }
        return dentBracket != nil && size != nil && photo != nil
    }

    var price: PanelPrice {
        Pricing.computePrice(panel: spec, state: self)
    }

    var spineSummary: String {
        let bracketText = dentBracket.map { "\($0.label) dents" } ?? "count —"
        let sizeText = size?.rawValue ?? "size —"
        let markupText = markups.isEmpty ? "none" : markups.map(\.rawValue).joined(separator: ", ")
        let priceText: String
        switch price {
        case .value(let v): priceText = "$\(v)"
        case .conventionalRepair: priceText = "CR"
        case .unavailable: priceText = "no est."
        }
        return "\(bracketText) · \(sizeText) · OS \(oversizeCount) · \(priceText) · markups: \(markupText)"
    }
}
