import SwiftUI

/// One tappable region on the vehicle diagram. Coordinates are in a fixed
/// 320×580 design space (matching the web build's SVG viewBox exactly), then
/// scaled to fit whatever size the view is actually given.
struct MapRegion {
    let code: String
    let label: String
    let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
    let rotated: Bool   // true for the two roof-rail strips (label reads vertically)
}

let vehicleMapCanvasSize = CGSize(width: 320, height: 580)

// Same geometry as the web version's VEHICLE_MAP_RECTS — panel doors/fenders/
// quarters narrowed to 71pt wide, roof rails widened to 34pt to give their
// labels room.
let vehicleMapRegions: [MapRegion] = [
    MapRegion(code: "FF-L",  label: "LFF",    x: 10,  y: 34,  w: 71,  h: 140, rotated: false),
    MapRegion(code: "HOOD",  label: "HOOD",   x: 86,  y: 34,  w: 158, h: 140, rotated: false),
    MapRegion(code: "FF-R",  label: "RFF",    x: 249, y: 34,  w: 71,  h: 140, rotated: false),

    MapRegion(code: "DR-FL", label: "LFD",    x: 10,  y: 174, w: 71,  h: 110, rotated: false),
    MapRegion(code: "RR-L",  label: "L RAIL", x: 86,  y: 174, w: 34,  h: 220, rotated: true),
    MapRegion(code: "ROOF",  label: "ROOF",   x: 120, y: 174, w: 90,  h: 220, rotated: false),
    MapRegion(code: "RR-R",  label: "R RAIL", x: 210, y: 174, w: 34,  h: 220, rotated: true),
    MapRegion(code: "DR-FR", label: "RFD",    x: 249, y: 174, w: 71,  h: 110, rotated: false),

    MapRegion(code: "DR-RL", label: "LRD",    x: 10,  y: 284, w: 71,  h: 110, rotated: false),
    MapRegion(code: "DR-RR", label: "RRD",    x: 249, y: 284, w: 71,  h: 110, rotated: false),

    MapRegion(code: "QP-L",  label: "LR¼",    x: 10,  y: 394, w: 71,  h: 140, rotated: false),
    MapRegion(code: "TRNK",  label: "TRUNK",  x: 86,  y: 394, w: 158, h: 140, rotated: false),
    MapRegion(code: "QP-R",  label: "RR¼",    x: 249, y: 394, w: 71,  h: 140, rotated: false),
]

struct VehicleMapView: View {
    @ObservedObject var deck: VehicleDeckState
    var onSelect: (String) -> Void   // called with the panel code that was tapped

    private func panelIndex(for code: String) -> Int? {
        panelDeck.firstIndex(where: { $0.code == code })
    }
    private func isComplete(_ code: String) -> Bool {
        guard let i = panelIndex(for: code) else { return false }
        return deck.panels[i].isComplete
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("PANEL MAP")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(hex: "FF6A1A"))
            Text("Tap a panel to jump to its card")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            GeometryReader { geo in
                let scale = min(geo.size.width / vehicleMapCanvasSize.width,
                                 geo.size.height / (vehicleMapCanvasSize.height + 40))
                ZStack {
                    Text("FRONT")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .position(x: vehicleMapCanvasSize.width / 2, y: -8)

                    ForEach(vehicleMapRegions, id: \.code) { region in
                        let done = isComplete(region.code)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(done ? Color(hex: "39D97A").opacity(0.32) : Color.white.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(done ? Color(hex: "39D97A") : Color.white.opacity(0.26), lineWidth: 2)
                            )
                            .overlay(
                                Text(region.label)
                                    .font(.system(size: region.rotated ? 10 : 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .rotationEffect(.degrees(region.rotated ? -90 : 0))
                            )
                            .frame(width: region.w, height: region.h)
                            .position(x: region.x + region.w / 2, y: region.y + region.h / 2)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(region.code) }
                    }

                    Text("REAR")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .position(x: vehicleMapCanvasSize.width / 2, y: vehicleMapCanvasSize.height + 14)
                }
                .frame(width: vehicleMapCanvasSize.width, height: vehicleMapCanvasSize.height)
                .scaleEffect(scale)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .frame(maxHeight: 460)

            Spacer(minLength: 4)
        }
        .padding(20)
    }
}

#Preview {
    VehicleMapView(deck: VehicleDeckState(label: "Vehicle A")) { _ in }
        .background(Color(hex: "14171A"))
}
