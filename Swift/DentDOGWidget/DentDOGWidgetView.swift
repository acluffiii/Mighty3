import SwiftUI
import WidgetKit

struct DentDOGWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: DentDOGEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        default:
            mediumLayout
        }
    }

    private var smallLayout: some View {
        Link(destination: URL(string: "dentdog://newEstimate")!) {
            VStack(alignment: .leading, spacing: 8) {
                brandRow
                Spacer()
                Text("Start New\nEstimate")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.10)) // --orange
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var mediumLayout: some View {
        Link(destination: URL(string: "dentdog://newEstimate")!) {
            HStack(spacing: 14) {
                brandRow
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Start New Estimate")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Tap to begin")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.10))
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var brandRow: some View {
        HStack(spacing: 8) {
            // "DentDogBadge" needs adding to this widget extension's OWN
            // asset catalog — widget extensions are a separate bundle and
            // can't read the main app target's Assets.xcassets directly.
            // Simplest fix: add a widget-extension target membership for
            // the same image asset in Xcode (select the asset, check both
            // targets in the File Inspector), or duplicate it into a
            // widget-local asset catalog. Noted in the Xcode setup steps.
            if let uiImage = UIImage(named: "DentDogBadge") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                // Falls back cleanly instead of crashing if the asset
                // hasn't been added to this target yet.
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.10))
            }
            Text("DENTDOG")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.10))
        }
    }
}
