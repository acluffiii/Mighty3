import SwiftUI

// MARK: - Theme

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255)
    }
}

enum Theme {
    static let ink = Color(hex: 0x15291a)
    static let panel = Color(hex: 0xf3f8e4)
    static let panel2 = Color(hex: 0xe2eecb)
    static let turf = Color(hex: 0x3c7f2a)
    static let stripeA = Color(hex: 0xa6dd6c)
    static let stripeB = Color(hex: 0x6fb843)
    static let sun = Color(hex: 0xffc92e)
    static let tomato = Color(hex: 0xe8493a)
    static let muted = Color(hex: 0x4c6243)
    static let pip = Color(hex: 0xd6dec8)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Chunky sticker look: fill, 3pt ink outline, hard ink shadow underneath.
struct Chunky: ViewModifier {
    var fill: Color = Theme.panel
    var radius: CGFloat = 18
    var drop: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.ink, lineWidth: 3))
            .background(RoundedRectangle(cornerRadius: radius).fill(Theme.ink).offset(y: drop))
    }
}

extension View {
    func chunky(_ fill: Color = Theme.panel, radius: CGFloat = 18, drop: CGFloat = 6) -> some View {
        modifier(Chunky(fill: fill, radius: radius, drop: drop))
    }

    /// Hard ink outline around text, like the web version's text-shadow.
    func inkOutline(_ w: CGFloat = 2) -> some View {
        shadow(color: Theme.ink, radius: 0, x: w, y: 0)
            .shadow(color: Theme.ink, radius: 0, x: -w, y: 0)
            .shadow(color: Theme.ink, radius: 0, x: 0, y: w)
            .shadow(color: Theme.ink, radius: 0, x: 0, y: -w)
            .shadow(color: Theme.ink, radius: 0, x: 0, y: w + 2)
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = .white
    var size: CGFloat = 20
    var wide = true

    func makeBody(configuration: Configuration) -> some View {
        ChunkyButtonBody(configuration: configuration, fill: fill, size: size, wide: wide)
    }

    private struct ChunkyButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let fill: Color
        let size: CGFloat
        let wide: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let pressed = configuration.isPressed && isEnabled
            configuration.label
                .font(Theme.font(size).monospacedDigit())
                .foregroundColor(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, size * 0.55)
                .padding(.horizontal, 14)
                .frame(maxWidth: wide ? .infinity : nil)
                .background(RoundedRectangle(cornerRadius: 12).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink, lineWidth: 3))
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink).offset(y: pressed ? 1 : 4))
                .offset(y: pressed ? 3 : 0)
                .opacity(isEnabled ? 1 : 0.45)
                .animation(.easeOut(duration: 0.06), value: pressed)
        }
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.font(12, .heavy))
            .tracking(1.4)
            .foregroundColor(Theme.muted)
    }
}

struct CashPill: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 6) {
            Text("$")
                .font(Theme.font(13))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Theme.sun))
                .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
            Text(grouped(amount))
                .font(Theme.font(21).monospacedDigit())
                .lineLimit(1)
        }
        .foregroundColor(Theme.ink)
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.vertical, 3)
        .chunky(radius: 20, drop: 3)
    }
}

// MARK: - Root

struct RootView: View {
    @StateObject private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SpriteView(scene: session.scene)
                .ignoresSafeArea()

            switch session.mode {
            case .title:
                if session.needsHandedness {
                    HandednessView(s: session)
                } else {
                    TitleView(s: session)
                }
            case .play, .finishing:
                HUDView(s: session)
            case .pause:
                HUDView(s: session)
                PauseView(s: session)
            case .done:
                DoneView(s: session)
            case .shop:
                GarageView(s: session)
            }

            BannerView(banner: session.banner)
        }
        .statusBarHidden(true)
        .onChange(of: scenePhase) { phase in
            if phase != .active { session.pause() }
        }
    }
}

// MARK: - Title

struct StripedLogo: View {
    private var words: some View {
        VStack(alignment: .leading, spacing: -16) {
            Text("Mow")
            Text("Money")
        }
        .font(Theme.font(78))
    }

    var body: some View {
        words
            .foregroundColor(.clear)
            .overlay(
                HStack(spacing: 0) {
                    ForEach(0..<30, id: \.self) { i in
                        Rectangle().fill(i % 2 == 0 ? Theme.stripeB : Theme.stripeA).frame(width: 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .mask(words)
            )
            .inkOutline(3)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mow Money")
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(Theme.font(20).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(Theme.font(11, .heavy))
                .foregroundColor(Theme.muted)
        }
        .foregroundColor(Theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel2))
    }
}

struct TitleView: View {
    @ObservedObject var s: GameSession

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Neighborhood lawn service")
                StripedLogo()
                Text("Stripe the lawn, spare the petunias, and save up for a bigger mower.")
                    .font(Theme.font(16, .bold))
                    .foregroundColor(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    StatTile(value: money(s.save.cash), label: "in the bank")
                    StatTile(value: "#\(s.save.level)", label: "next job")
                    StatTile(value: grouped(s.save.sqft), label: "sq ft mowed")
                }
                Button("Start job #\(s.save.level)") { s.startJob() }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.sun))
                Button("Garage") { s.openGarage() }
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.top, 4)
                Text("Steer with the stick in the bottom \(s.isRightHanded ? "right" : "left") corner.")
                    .font(Theme.font(13, .bold))
                    .foregroundColor(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                HStack(spacing: 18) {
                    Button(s.isRightHanded ? "Controls: right hand" : "Controls: left hand") { s.toggleHandedness() }
                    Button(s.save.muted ? "Sound: off" : "Sound: on") { s.toggleMute() }
                }
                .font(Theme.font(13, .heavy))
                .foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity)
            }
            .padding(22)
            .frame(maxWidth: 430)
            .chunky()
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [.clear, Color.black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
    }
}

// MARK: - HUD

struct StripedBar: View {
    let fraction: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Color(hex: 0x2f6a22)
                HStack(spacing: 0) {
                    ForEach(0..<40, id: \.self) { i in
                        Rectangle().fill(i % 2 == 0 ? Theme.stripeA : Theme.stripeB).frame(width: 8)
                    }
                }
                .frame(width: g.size.width * CGFloat(min(max(fraction, 0), 1)), alignment: .leading)
                .clipped()
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.ink, lineWidth: 2))
        .animation(.linear(duration: 0.15), value: fraction)
    }
}

struct HUDView: View {
    @ObservedObject var s: GameSession

    var body: some View {
        let h = s.hud
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                CashPill(amount: h.cash)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 3) {
                    Text(h.jobName)
                        .font(Theme.font(13, .heavy))
                        .lineLimit(1)
                    StripedBar(fraction: Double(h.pct) / 100)
                    HStack {
                        Text("\(h.pct)% mowed")
                        Spacer(minLength: 6)
                        Text("\(clock(Double(h.time))) · par \(clock(Double(h.par)))")
                            .foregroundColor(h.time > h.par ? Theme.tomato : Theme.ink)
                    }
                    .font(Theme.font(12, .heavy).monospacedDigit())
                }
                .foregroundColor(Theme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .chunky(radius: 12, drop: 3)
                .allowsHitTesting(false)
                Button { s.pause() } label: {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1).frame(width: 4, height: 14)
                        RoundedRectangle(cornerRadius: 1).frame(width: 4, height: 14)
                    }
                    .foregroundColor(Theme.ink)
                    .frame(width: 44, height: 44)
                    .chunky(radius: 12, drop: 3)
                }
                .accessibilityLabel("Pause")
            }
            .frame(maxWidth: 720)

            VStack(spacing: 4) {
                if h.combo > 1 {
                    Text("x\(h.combo) combo")
                        .font(Theme.font(28))
                        .foregroundColor(Theme.sun)
                        .inkOutline(2)
                        .id(h.combo)
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                }
                if h.showMeter {
                    Capsule().fill(Color.black.opacity(0.35))
                        .frame(width: 90, height: 6)
                        .overlay(
                            Capsule().fill(Theme.sun)
                                .frame(width: 90 * CGFloat(h.comboFill), height: 6),
                            alignment: .leading)
                }
                HStack(spacing: 6) {
                    ForEach(h.powers) { p in
                        Text("\(p.kind.label) \(p.seconds)s")
                            .font(Theme.font(12, .black).monospacedDigit())
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(p.kind.color)))
                            .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: h.combo)
            .allowsHitTesting(false)

            Spacer()

            HStack {
                if s.isRightHanded {
                    MinimapView(image: s.minimap, dot: h.mowerDot)
                    Spacer()
                } else {
                    Spacer()
                    MinimapView(image: s.minimap, dot: h.mowerDot)
                }
            }
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}

struct MinimapView: View {
    let image: CGImage?
    let dot: CGPoint

    var body: some View {
        if let img = image {
            let aspect = CGFloat(img.width) / CGFloat(max(img.height, 1))
            let w = min(130, aspect * 96)
            Image(decorative: img, scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: w, height: w / aspect)
                .overlay(
                    GeometryReader { g in
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                            .frame(width: 9, height: 9)
                            .position(x: dot.x * g.size.width, y: dot.y * g.size.height)
                    }
                )
                .padding(3)
                .background(Theme.ink)
        }
    }
}

// MARK: - Pause

// MARK: - Handedness (first launch)

struct HandednessView: View {
    @ObservedObject var s: GameSession

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Before you mow")
                Text("Which hand do you steer with?")
                    .font(Theme.font(30))
                    .foregroundColor(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("The joystick goes in the bottom corner on that side. You can change this later.")
                    .font(Theme.font(15, .bold))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    handButton(right: false)
                    handButton(right: true)
                }
                .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: 430)
            .chunky()
            .padding(.horizontal, 16)
        }
    }

    private func handButton(right: Bool) -> some View {
        Button {
            s.setHandedness(rightHanded: right)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 40, weight: .bold))
                    .scaleEffect(x: right ? 1 : -1, y: 1)
                Text(right ? "Right hand" : "Left hand")
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(ChunkyButtonStyle(fill: Theme.sun))
    }
}

struct PauseView: View {
    @ObservedObject var s: GameSession

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("Paused").font(Theme.font(34)).foregroundColor(Theme.ink)
                Button("Resume") { s.resume() }.buttonStyle(ChunkyButtonStyle(fill: Theme.sun))
                Button(s.save.muted ? "Sound: off" : "Sound: on") { s.toggleMute() }.buttonStyle(ChunkyButtonStyle())
                Button(s.isRightHanded ? "Controls: right hand" : "Controls: left hand") { s.toggleHandedness() }
                    .buttonStyle(ChunkyButtonStyle())
                Button("Quit job") { s.quitJob() }.buttonStyle(ChunkyButtonStyle())
                Text("You keep what you've earned on this lawn so far.")
                    .font(Theme.font(13, .bold))
                    .foregroundColor(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(22)
            .frame(maxWidth: 400)
            .chunky()
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Job done

struct DoneView: View {
    @ObservedObject var s: GameSession
    @State private var shownStars = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            if let r = s.result {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Job #\(r.level) · \(r.lawnName)")
                        Text(["Done is done", "Decent cut", "Sharp work", "Magazine lawn"][min(r.stars, 3)])
                            .font(Theme.font(34))
                            .foregroundColor(Theme.ink)
                        HStack(spacing: 10) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 46))
                                    .foregroundColor(i < shownStars ? Theme.sun : Color(hex: 0xc9d3b7))
                                    .inkOutline(2)
                                    .scaleEffect(i < shownStars ? 1 : 0.85)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(r.checks) { c in
                                HStack(spacing: 10) {
                                    Image(systemName: c.ok ? "checkmark" : "xmark")
                                        .font(.system(size: 11, weight: .black))
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(c.ok ? Theme.stripeA : Color(hex: 0xc9d3b7)))
                                        .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                                    Text(c.label).font(Theme.font(14, .heavy))
                                    Spacer()
                                    Text(c.value).font(Theme.font(13, .bold).monospacedDigit()).foregroundColor(Theme.muted)
                                }
                                .foregroundColor(Theme.ink)
                            }
                        }

                        VStack(spacing: 4) {
                            ledgerRow("Mowing, \(grouped(r.sqft)) sq ft", money(r.earn))
                            ledgerRow("Job fee", money(r.fee))
                            ledgerRow("Tip for \(r.stars) star\(r.stars == 1 ? "" : "s")", money(r.tip))
                            if r.penalty > 0 {
                                ledgerRow("Flower damage", "−" + money(r.penalty), color: Theme.tomato)
                            }
                            Divider().overlay(Theme.ink.opacity(0.3))
                            HStack {
                                Text("Paid")
                                Spacer()
                                Text(money(r.total))
                            }
                            .font(Theme.font(22).monospacedDigit())
                        }
                        .foregroundColor(Theme.ink)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel2))

                        HStack(spacing: 10) {
                            Button("Garage") { s.openGarage() }.buttonStyle(ChunkyButtonStyle())
                            Button("Next job #\(s.save.level)") { s.startJob() }.buttonStyle(ChunkyButtonStyle(fill: Theme.sun))
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: 430)
                    .chunky()
                    .padding(16)
                    .frame(maxWidth: .infinity)
                }
                .onAppear {
                    shownStars = 0
                    for i in 0..<r.stars {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { shownStars = i + 1 }
                            s.haptics.coin()
                        }
                    }
                }
            }
        }
    }

    private func ledgerRow(_ label: String, _ value: String, color: Color = Theme.ink) -> some View {
        HStack {
            Text(label).font(Theme.font(14, .bold))
            Spacer()
            Text(value).font(Theme.font(14, .black).monospacedDigit())
        }
        .foregroundColor(color)
    }
}

// MARK: - Garage

struct GarageView: View {
    @ObservedObject var s: GameSession

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Garage").font(Theme.font(34)).foregroundColor(Theme.ink)
                        Spacer()
                        CashPill(amount: Int(s.save.cash))
                    }
                    Eyebrow(text: "Tune-ups").padding(.top, 4)
                    ForEach(Catalog.upgrades, id: \.id) { u in upgradeRow(u) }
                    Eyebrow(text: "Mowers").padding(.top, 4)
                    ForEach(Catalog.tiers.indices, id: \.self) { i in tierRow(i) }
                    HStack(spacing: 10) {
                        Button("Back") { s.closeGarage() }.buttonStyle(ChunkyButtonStyle())
                        Button("Start job #\(s.save.level)") { s.startJob() }.buttonStyle(ChunkyButtonStyle(fill: Theme.sun))
                    }
                    .padding(.top, 4)
                }
                .padding(22)
                .frame(maxWidth: 520)
                .chunky()
                .padding(16)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func upgradeRow(_ u: Upgrade) -> some View {
        let lv = s.save.level(of: u.id)
        let maxed = lv >= Catalog.upgradeMax
        let cost = s.save.cost(of: u.id)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(u.name).font(Theme.font(16, .black))
                Text("\(u.desc) · level \(lv)/\(Catalog.upgradeMax)").font(Theme.font(12, .bold)).foregroundColor(Theme.muted)
                HStack(spacing: 3) {
                    ForEach(0..<Catalog.upgradeMax, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < lv ? Theme.turf : Theme.pip)
                            .frame(width: 12, height: 6)
                    }
                }
                .padding(.top, 3)
            }
            .foregroundColor(Theme.ink)
            Spacer(minLength: 4)
            Button(maxed ? "Maxed" : money(cost)) { s.buy(u.id) }
                .buttonStyle(ChunkyButtonStyle(fill: maxed ? .white : Theme.sun, size: 16, wide: false))
                .frame(minWidth: 92)
                .disabled(maxed || s.save.cash < cost)
        }
        .padding(.vertical, 10)
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink, lineWidth: 2))
    }

    private func tierRow(_ i: Int) -> some View {
        let t = Catalog.tiers[i]
        let owned = s.save.owned.contains(i)
        let current = s.save.tier == i
        let label = current ? "Driving" : (owned ? "Use" : money(t.price))
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(t.color))
                .frame(width: 34, height: 34)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.ink, lineWidth: 2))
            VStack(alignment: .leading, spacing: 2) {
                Text(t.name).font(Theme.font(16, .black))
                Text("\(deckInches(t.deck))-inch deck · \(mph(t.speed)) mph · \(t.blurb)")
                    .font(Theme.font(12, .bold))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(Theme.ink)
            Spacer(minLength: 4)
            Button(label) { s.selectTier(i) }
                .buttonStyle(ChunkyButtonStyle(fill: owned ? .white : Theme.sun, size: 16, wide: false))
                .frame(minWidth: 92)
                .disabled(current || (!owned && s.save.cash < t.price))
        }
        .padding(.vertical, 10)
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(current ? Color(hex: 0xeef8dc) : Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink, lineWidth: 2))
    }
}

// MARK: - Banner

struct BannerView: View {
    let banner: BannerInfo?

    var body: some View {
        VStack {
            Spacer().frame(height: 170)
            if let b = banner {
                VStack(spacing: 8) {
                    Text(b.title)
                        .font(Theme.font(44))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .inkOutline(3)
                    if let sub = b.subtitle {
                        Text(sub)
                            .font(Theme.font(14, .heavy))
                            .foregroundColor(Theme.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .chunky(radius: 16, drop: 3)
                    }
                }
                .padding(.horizontal, 16)
                .id(b.id)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}
