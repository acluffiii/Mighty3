import AppIntents

/// Scaffold for a genuinely-interactive widget action (one that runs code
/// without opening the app — e.g. a future "quick log a panel count"
/// button). NOT what drives the current "Start New Estimate" button —
/// that one just needs to open the app to a specific screen, and a plain
/// Link(destination:) with the dentdog:// URL scheme does that more simply
/// and on a wider iOS version range than an App Intent button requires.
/// See DentDOGWidgetView.swift for what's actually wired up today.
///
/// Kept as a real, working example since interactive App Intents are the
/// right tool the moment a button needs to DO something (write data,
/// increment a counter) rather than just navigate — at that point this is
/// the pattern to extend.
struct StartNewEstimateIntent: AppIntent {
    static var title: LocalizedStringResource = "Start New Estimate"
    static var description = IntentDescription("Opens DentDOG to a fresh estimate.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
