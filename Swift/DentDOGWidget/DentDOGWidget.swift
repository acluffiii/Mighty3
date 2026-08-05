import WidgetKit
import SwiftUI

struct DentDOGEntry: TimelineEntry {
    let date: Date
    // Placeholder fields for the data-driven version — currently unused
    // since there's no shared persistence yet (see the file header note
    // in DentDOGWidgetBundle.swift for what that needs). Left in the
    // Entry struct now so wiring up real data later is a small change
    // to the Provider, not a redesign of the widget itself.
    let lastEstimateTotal: Int?
    let panelsToday: Int?
}

struct DentDOGTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DentDOGEntry {
        DentDOGEntry(date: Date(), lastEstimateTotal: nil, panelsToday: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DentDOGEntry) -> Void) {
        completion(DentDOGEntry(date: Date(), lastEstimateTotal: nil, panelsToday: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DentDOGEntry>) -> Void) {
        // Single static entry, never refreshes — .never is correct as
        // long as this widget has no real data source. Once shared
        // persistence exists, this should read from the App Group
        // container here and set a real refresh policy (e.g. .after(_:)
        // every time an estimate is saved, via WidgetCenter.shared.reloadTimelines
        // called from the main app after a save).
        let entry = DentDOGEntry(date: Date(), lastEstimateTotal: nil, panelsToday: nil)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct DentDOGWidget: Widget {
    let kind: String = "DentDOGWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DentDOGTimelineProvider()) { entry in
            DentDOGWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0x14/255, green: 0x10/255, blue: 0x0B/255) // matches --steel-0 from the web build's theme
                }
        }
        .configurationDisplayName("DentDOG")
        .description("Quickly start a new estimate.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
