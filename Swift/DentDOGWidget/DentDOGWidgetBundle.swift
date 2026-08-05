import WidgetKit
import SwiftUI

/* ============================================================
   PREREQUISITE FOR DATA-DRIVEN WIDGETS (estimate total, panel count)
   ============================================================
   This widget target currently only ships the deep-link "Start New
   Estimate" button, which needs no shared data. Showing real numbers
   (last estimate total, today's panel count) needs two things that don't
   exist yet in this Swift project:

   1. Persistence in the main app. Nothing in DentDOG/PanelStackView.swift
      or Models.swift saves an estimate anywhere right now — closing the
      app loses everything, same gap that's been in this project's known-
      issues list since early in its build. The web build solved this with
      IndexedDB; the Swift equivalent would be SwiftData or a simple JSON
      file written to disk.

   2. An App Group. A widget extension runs as a separate process/target
      from the main app — it cannot read the main app's local storage
      directly, persisted or not. Both targets need to be added to the
      same App Group (in Xcode: target -> Signing & Capabilities -> +
      Capability -> App Groups, same group ID checked on both the main
      app target and this widget extension target), and persistence needs
      to write into that shared container (e.g.
      FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:))
      rather than the app's normal sandboxed Documents directory.

   Once both exist, DentDOGTimelineProvider.getTimeline(in:completion:) is
   the only file that needs to change — read from the shared container,
   populate DentDOGEntry's lastEstimateTotal/panelsToday fields, and this
   view already has those fields ready to display.
   ============================================================ */

@main
struct DentDOGWidgetBundle: WidgetBundle {
    var body: some Widget {
        DentDOGWidget()
    }
}
