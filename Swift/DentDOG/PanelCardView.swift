import SwiftUI

struct PanelCardView: View {
    @ObservedObject var state: PanelState
    var isFront: Bool
    var tiltMagnitude: Double   // 0...1, drives the hidden spine reveal, either pivot direction
    var onRequestCapture: () -> Void
    var onRequestMeasure: () -> Void = {}

    private let cardWidth: CGFloat = 272
    private let cardHeight: CGFloat = 444
    private let corner: CGFloat = 16

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(.ultraThinMaterial)

            // translucent photo thumbnail, sits behind the fields
            if let photo = state.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .opacity(state.isComplete ? 0.40 : 0.32)
            }

            Group {
                if state.spec.kind == .photo {
                    docCardBody
                } else {
                    estimateCardBody
                }
            }
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 12, trailing: 16))

            statusPill

            // colored wipe that washes red away and confirms green on completion
            if state.justCompleted {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        RadialGradient(colors: [Color(hex: "39D97A").opacity(0.6), Color(hex: "39D97A").opacity(0)],
                                       center: UnitPoint(x: 0.5, y: 0.58), startRadius: 4, endRadius: 260)
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.1).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: glowColor, radius: state.isComplete ? 20 : 0, x: 0, y: 0)
        .scaleEffect(state.justCompleted ? 1.045 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: state.justCompleted)
        .overlay(alignment: .bottom) {
            // hidden spine — reads as a thin edge until the deck is pivoted, either direction
            Text(state.spineSummary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(width: cardWidth - 20, height: 27, alignment: .leading)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .offset(y: 27 * (1 - tiltMagnitude) + 5) // folds under the card until tilted
                .opacity(tiltMagnitude)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Estimate card (13 damage panels)

    private var estimateCardBody: some View {
        VStack(alignment: .leading, spacing: 9) {
            header(subtitle: "PANEL \(state.spec.code)")
            priceLine
            bracketRow
            sizeRow
            measureRow
            oversizeRow
            markupRow
            Spacer(minLength: 4)
            photoRow
        }
    }

    /// LiDAR/marker measurement entry point — sits right under the manual
    /// size chips so it reads as "or measure it instead" rather than a
    /// separate unrelated feature.
    private var measureRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onRequestMeasure) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Measure with LiDAR")
                        .font(.system(size: 12.5, weight: .bold))
                    Spacer()
                    if let m = state.lastMeasurement, m.widthMM != nil {
                        Text(m.formatted())
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Color(hex: "39D97A"))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "FF6A1A").opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Doc card (7 required photos — VIN, corners, plate, odometer)

    private var docCardBody: some View {
        VStack(alignment: .leading, spacing: 9) {
            header(subtitle: "REQUIRED PHOTO · \(state.spec.code)")
            Spacer(minLength: 4)
            photoRow
        }
    }

    private func header(subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(state.spec.name)
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(1.5)
        }
    }

    private var priceLine: some View {
        Group {
            switch state.price {
            case .value(let v):
                Text("$\(v)")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "FF6A1A"))
            case .conventionalRepair:
                Text("CR — conventional repair / replace")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "FF4D4D"))
            case .unavailable:
                Text("select size + count for est.")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private var bracketRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Dent Count")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(dentBrackets) { b in
                    bracketChip(b, selected: state.dentBracket == b) {
                        state.dentBracket = (state.dentBracket == b) ? nil : b
                    }
                }
            }
        }
    }

    private func bracketChip(_ bracket: DentBracket, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(bracket.label)
                .font(.system(size: 11.5, weight: .heavy))
                .foregroundStyle(selected ? bracket.textColor : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selected ? AnyShapeStyle(bracket.color) : AnyShapeStyle(bracket.color.opacity(0.18)))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(bracket.color.opacity(selected ? 1 : 0.42), lineWidth: selected ? 1.5 : 1))
                .shadow(color: selected ? bracket.color.opacity(0.55) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }

    private var oversizeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Oversize Count")
            HStack(spacing: 9) {
                stepperButton("−", size: 40, font: 20) { state.oversizeCount = max(0, state.oversizeCount - 1) }
                Text("\(state.oversizeCount)")
                    .font(.system(size: 19, weight: .heavy))
                    .frame(minWidth: 32)
                    .foregroundStyle(.white)
                stepperButton("+", size: 40, font: 20) { state.oversizeCount = min(10, state.oversizeCount + 1) }
            }
        }
    }

    private func stepperButton(_ symbol: String, size: CGFloat, font: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: font, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }

    private var sizeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Dent Size")
            HStack(spacing: 6) {
                ForEach(DentSize.allCases) { s in
                    chip(text: s.rawValue, selected: state.size == s) {
                        state.size = (state.size == s) ? nil : s
                    }
                }
            }
        }
    }

    private var markupRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Markups (optional)")
            HStack(spacing: 6) {
                ForEach(Markup.allCases) { m in
                    markupButton(text: m.rawValue, selected: state.markups.contains(m)) {
                        if state.markups.contains(m) { state.markups.remove(m) } else { state.markups.insert(m) }
                    }
                }
            }
        }
    }

    /// Only visible once a photo exists — no instructional placeholder, matches the web build.
    private var photoRow: some View {
        Group {
            if state.photo != nil {
                HStack(spacing: 8) {
                    Text("✓  PHOTO CAPTURED")
                        .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "39D97A"))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "39D97A").opacity(0.45), lineWidth: 1.5))
                }
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle().fill(state.isComplete ? Color(hex: "39D97A") : Color(hex: "FF4D4D")).frame(width: 7, height: 7)
            Text(state.isComplete ? "SAVED" : "INCOMPLETE")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(state.isComplete ? Color(hex: "39D97A") : Color(hex: "FF4D4D"))
        }
        .padding(.top, 14)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(1.1)
            .foregroundStyle(.white.opacity(0.55))
    }

    private func chip(text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? AnyShapeStyle(orangeGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color(hex: "FF6A1A") : .white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func markupButton(text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? AnyShapeStyle(orangeGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color(hex: "FF6A1A") : .white.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }

    private var orangeGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "FF6A1A").opacity(0.35), Color(hex: "FF6A1A").opacity(0.14)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Only complete (green) cards get a status color at all — incomplete cards
    /// stay plain frosted glass, no red glow (matches the web build).
    private var borderColor: Color {
        state.isComplete ? Color(hex: "39D97A").opacity(0.55) : Color.white.opacity(0.13)
    }
    private var glowColor: Color {
        state.isComplete ? Color(hex: "39D97A").opacity(0.35) : .clear
    }
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB,
                   red: Double((v >> 16) & 0xFF) / 255,
                   green: Double((v >> 8) & 0xFF) / 255,
                   blue: Double(v & 0xFF) / 255,
                   opacity: 1)
    }
}
