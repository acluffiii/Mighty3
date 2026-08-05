import SwiftUI

/// Connect/disconnect UI for each insurer integration. Purely OAuth
/// plumbing right now — tapping "Connect" runs a real sign-in flow, but
/// there's no actual estimate push/pull wired up yet, since that depends
/// on each provider's specific data format once you're approved as a
/// partner. This view is the front door for that future work.
struct InsurerConnectView: View {
    @StateObject private var mitchell = OAuthClient(config: InsurerProvider.mitchell)
    @StateObject private var ccc = OAuthClient(config: InsurerProvider.ccc)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Insurer Connections")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.08), in: Circle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            Text("Sign in to enable pushing estimates directly into each platform. "
                 + "Both use real OAuth 2.0 — client IDs are placeholders until "
                 + "DentDOG is registered with each provider's developer program.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            VStack(spacing: 12) {
                providerRow(client: mitchell, subtitle: "Public developer portal — RepairCenter Transactional API")
                providerRow(client: ccc, subtitle: "Secure Share marketplace — requires CIECA membership")
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color(hex: "14171A").ignoresSafeArea())
    }

    @ViewBuilder
    private func providerRow(client: OAuthClient, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(client.config.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                statusPill(connected: client.isConnected)
            }

            HStack(spacing: 10) {
                Button(action: { client.isConnected ? client.signOut() : client.signIn() }) {
                    Text(client.isConnected ? "Disconnect" : "Connect")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(client.isConnected ? .white.opacity(0.8) : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(client.isConnected ? Color.white.opacity(0.08) : Color(hex: "FF6A1A"), in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(client.isAuthenticating)

                if client.isAuthenticating {
                    ProgressView().tint(.white)
                }
            }

            if let error = client.lastError {
                Text(error)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Color(hex: "FF4D4D"))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func statusPill(connected: Bool) -> some View {
        HStack(spacing: 5) {
            Circle().fill(connected ? Color(hex: "39D97A") : Color.white.opacity(0.3)).frame(width: 7, height: 7)
            Text(connected ? "CONNECTED" : "NOT CONNECTED")
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(connected ? Color(hex: "39D97A") : .white.opacity(0.4))
        }
    }
}

#Preview {
    InsurerConnectView()
}
