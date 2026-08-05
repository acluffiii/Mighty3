import SwiftUI

@main
struct HailDeckApp: App {
    var body: some Scene {
        WindowGroup {
            PanelStackView()
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
                .onOpenURL { url in
                    // dentdog://newEstimate — sent by the DentDOG widget's
                    // "Start New Estimate" button. OAuth callbacks
                    // (dentdog://oauth/...) are handled separately by
                    // ASWebAuthenticationSession and don't come through here.
                    guard url.scheme == "dentdog" else { return }
                    if url.host == "newEstimate" {
                        NotificationCenter.default.post(name: .startNewEstimate, object: nil)
                    }
                }
        }
    }
}
