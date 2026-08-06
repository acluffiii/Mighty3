import SwiftUI
import UIKit

struct PanelStackView: View {
    @StateObject private var deckA = VehicleDeckState(label: "Vehicle A")
    @StateObject private var deckB = VehicleDeckState(label: "Vehicle B")
    @State private var deckOrder: [Int] = [0, 1]   // deckOrder[0] = active/front vehicle

    @State private var order: [Int]
    @State private var dragTranslation: CGSize = .zero
    @State private var gestureMode: GestureMode = .none
    @State private var tiltDegrees: Double = 0
    @State private var switchCommitted = false

    @State private var captureIndex: Int? = nil
    @State private var showCamera = false
    @State private var showLidarMeasure = false
    @State private var showMap = false
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    @State private var switchLabelVisible = false
    @State private var showInsurerConnect = false
    @State private var showImporter = false

    private let offsetStep: CGFloat = 16
    private let maxVisibleDepth = 6
    private let tiltMax: Double = 24
    private let tiltSensitivity: Double = 0.16
    private let axisLockThreshold: CGFloat = 9
    private let deckSwitchThreshold: CGFloat = 55
    private let orderStorageKey = "dentdog.deckOrder"

    enum GestureMode { case none, shuffle, tilt }

    init() {
        _order = State(initialValue: Self.loadOrder())
    }

    // MARK: - Derived state

    private var decks: [VehicleDeckState] { [deckA, deckB] }
    private var frontDeck: VehicleDeckState { decks[deckOrder[0]] }
    private var panels: [PanelState] { frontDeck.panels }
    // NOTE: unlike the web build, there's no dimmed "peek at the deck behind"
    // visual here yet — tilting still switches vehicles once the swipe
    // threshold is crossed, it just doesn't show the second deck fading in
    // first. Wiring that up would mean rendering `decks[deckOrder[1]]`'s
    // cards behind the front stack with an opacity tied to tiltMagnitude.

    private static func loadOrder() -> [Int] {
        let defaultOrder = Array(panelDeck.indices)
        guard let saved = UserDefaults.standard.array(forKey: "dentdog.deckOrder") as? [Int] else {
            return defaultOrder
        }
        let valid = saved.count == defaultOrder.count && Set(saved) == Set(defaultOrder)
        return valid ? saved : defaultOrder
    }
    private func persistOrder() {
        UserDefaults.standard.set(order, forKey: orderStorageKey)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            deck
                .padding(.bottom, 26)
            hint
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(colors: [Color(hex: "232A30"), Color(hex: "14171A")],
                            center: UnitPoint(x: 0.5, y: -0.1), startRadius: 20, endRadius: 500)
                .ignoresSafeArea()
        )
        .overlay(alignment: .topLeading) {
            toolButton(system: "square.grid.2x2") { showMap = true }
                .padding(14)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                toolButton(system: "link") { showInsurerConnect = true }
                toolButton(system: "square.and.arrow.up", action: exportPDF)
            }
            .padding(14)
        }
        .sheet(isPresented: $showCamera) {
            if let i = captureIndex {
                CameraViewfinder(panelName: panels[i].spec.name) { image in
                    let panel = panels[i]
                    panel.photo = image
                    if panel.isComplete && !panel.justCompleted {
                        panel.justCompleted = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { panel.justCompleted = false }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showLidarMeasure) {
            if let i = captureIndex {
                LidarMeasureView(panelName: panels[i].spec.name) { image, measurement in
                    let panel = panels[i]
                    panel.lastMeasurement = measurement
                    if let suggested = measurement.suggestedSize {
                        panel.size = suggested
                    }
                    if let image {
                        panel.photo = image
                    }
                    if panel.isComplete && !panel.justCompleted {
                        panel.justCompleted = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { panel.justCompleted = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showMap) {
            VehicleMapView(deck: frontDeck) { code in
                if let idx = panelDeck.firstIndex(where: { $0.code == code }) {
                    bringToFront(idx)
                }
                showMap = false
            }
            .background(Color(hex: "14171A").ignoresSafeArea())
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .sheet(isPresented: $showInsurerConnect) {
            InsurerConnectView()
        }
        .sheet(isPresented: $showImporter) {
            PhotoImporter { image in
                guard let frontIndex = order.first else { return }
                let panel = panels[frontIndex]
                panel.photo = image
                if panel.isComplete && !panel.justCompleted {
                    panel.justCompleted = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { panel.justCompleted = false }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startNewEstimate)) { _ in
            deckA.reset()
            deckB.reset()
        }
    }

    private func toolButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
        }
    }

    private func exportPDF() {
        let data = EstimateExporter.makePDF(deck: frontDeck)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DentDOG_\(frontDeck.label.replacingOccurrences(of: " ", with: "_"))")
            .appendingPathExtension("pdf")
        do {
            try data.write(to: url)
            shareURL = url
            showShareSheet = true
        } catch {
            // Writing to the temp directory failing would be unusual, but don't
            // crash the app over an export — just silently no-op.
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("DENTDOG · \(frontDeck.label.uppercased())")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Color(hex: "FF6A1A"))
            Text("Vehicle Panels")
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(.white)
            Text("\(frontDeck.savedCount)/\(panels.count) saved · Est. $\(frontDeck.estimateTotal)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))

            // Header-level, not per-card — matches a fix made on the web
            // build after the equivalent per-card button was hard to spot
            // on a real device. Targets whichever panel is currently on
            // top of the front deck's browsing order.
            Button(action: { showImporter = true }) {
                Text("⇧ Import Photo (current panel)")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Color(hex: "FF6A1A"), in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color(hex: "FF6A1A").opacity(0.55), radius: 12, y: 6)
            }
            .padding(.top, 6)
        }
        .padding(.top, 18)
    }

    private var hint: some View {
        Text("Double-tap to capture · Swipe left/right to browse · Tilt, then keep swiping to switch vehicles")
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .multilineTextAlignment(.center)
    }

    // MARK: - Deck

    private var deck: some View {
        ZStack(alignment: .bottom) {
            ForEach(Array(order.enumerated()), id: \.offset) { pos, panelIndex in
                let depth = min(pos, maxVisibleDepth)
                let front = pos == 0

                PanelCardView(
                    state: panels[panelIndex],
                    isFront: front,
                    tiltMagnitude: front ? tiltMagnitude : 0,
                    onRequestCapture: { requestCapture(panelIndex) },
                    onRequestMeasure: { requestMeasure(panelIndex) }
                )
                .scaleEffect(1 - CGFloat(depth) * 0.025)
                .offset(x: CGFloat(depth) * offsetStep + (front ? dragTranslation.width : 0))
                .opacity(pos > maxVisibleDepth ? 0 : 1 - Double(depth) * 0.08)
                .zIndex(Double(100 - pos))
                .allowsHitTesting(pos <= maxVisibleDepth)
                .onTapGesture { if !front { bringToFront(panelIndex) } }
                .ifFront(front) { $0.gesture(frontCardGesture(panelIndex)) }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: order)
            }
        }
        .rotation3DEffect(.degrees(tiltDegrees), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.4)
        // .id() forces SwiftUI to treat this as a brand-new view whenever the
        // active vehicle changes, which is what makes .transition() below
        // actually fire — without it, the cards would just snap to the new
        // deck's content instantly, no animation, since it'd read as the
        // "same" view just re-rendering with different data.
        .id(deckOrder[0])
        .transition(.asymmetric(
            insertion: .scale(scale: 0.86).combined(with: .opacity).combined(with: .offset(y: 14)),
            removal: .scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(y: -14))
        ))
        .overlay {
            if switchLabelVisible {
                Text(frontDeck.label.uppercased())
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(.black.opacity(0.6), in: Capsule())
                    .overlay(Capsule().stroke(Color(hex: "FF6A1A"), lineWidth: 2))
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    private var tiltMagnitude: Double { min(1, abs(tiltDegrees) / tiltMax) }

    // MARK: - Gestures

    private func frontCardGesture(_ index: Int) -> some Gesture {
        // Native double-tap — reliable, doesn't compete with the drag gesture below.
        let doubleTap = TapGesture(count: 2).onEnded { requestCapture(index) }

        let drag = DragGesture(minimumDistance: 0)
            .onChanged { value in
                let t = value.translation
                if gestureMode == .none {
                    guard abs(t.width) > axisLockThreshold || abs(t.height) > axisLockThreshold else { return }
                    gestureMode = abs(t.height) > abs(t.width) ? .tilt : .shuffle
                }
                switch gestureMode {
                case .shuffle:
                    dragTranslation = CGSize(width: t.width, height: 0)

                case .tilt:
                    guard !switchCommitted else { return }
                    let deg = max(-tiltMax, min(tiltMax, Double(-t.height) * tiltSensitivity))
                    tiltDegrees = deg

                    // Tilt the deck, then keep swiping (either direction) while it's
                    // tilted — that continued motion sends the top deck to the back,
                    // same combined gesture as the web build.
                    let peekRatio = max(0, deg) / tiltMax
                    if peekRatio > 0.35 && abs(t.width) > deckSwitchThreshold {
                        switchCommitted = true
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            tiltDegrees = 0
                        }
                        switchVehicle()
                    }

                case .none:
                    break
                }
            }
            .onEnded { value in
                defer { gestureMode = .none; switchCommitted = false }
                guard !switchCommitted else { return }
                switch gestureMode {
                case .shuffle:
                    let dx = value.translation.width
                    dragTranslation = .zero
                    if dx < -60 { advance(1) }
                    else if dx > 60 { advance(-1) }
                case .tilt:
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                        tiltDegrees = 0
                    }
                case .none:
                    break
                }
            }

        return doubleTap.simultaneously(with: drag)
    }

    private func switchVehicle() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            deckOrder.append(deckOrder.removeFirst())
            switchLabelVisible = true
        }
        // Auto-dismiss the "VEHICLE B" label after a beat — this is a
        // fire-and-forget confirmation, not something the user dismisses.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.3)) {
                switchLabelVisible = false
            }
        }
    }

    private func requestCapture(_ index: Int) {
        captureIndex = index
        showCamera = true
    }

    private func requestMeasure(_ index: Int) {
        captureIndex = index
        showLidarMeasure = true
    }

    private func advance(_ dir: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if dir == 1 {
                let first = order.removeFirst()
                order.append(first)
            } else {
                let last = order.removeLast()
                order.insert(last, at: 0)
            }
        }
        persistOrder()
    }

    private func bringToFront(_ index: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            order.removeAll { $0 == index }
            order.insert(index, at: 0)
        }
        persistOrder()
    }
}

#Preview {
    PanelStackView()
}

private extension View {
    @ViewBuilder
    func ifFront<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
