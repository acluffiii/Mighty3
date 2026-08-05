import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

// ============================================================
// OAuth 2.0 client — Authorization Code flow with PKCE, using
// ASWebAuthenticationSession (Apple's standard, secure pattern for OAuth
// in a native app — RFC 8252). This is real, functional OAuth
// infrastructure; what's NOT real yet is the client credentials below,
// since those only exist once you've actually registered DentDOG with
// each provider's developer program.
// ============================================================

/// One OAuth 2.0 provider's configuration.
struct OAuthProviderConfig {
    let name: String
    let clientID: String
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let redirectURI: URL
    let scopes: [String]
}

enum InsurerProvider {
    /// Mitchell has a public developer portal (developer.mitchell.com) with
    /// app-key registration and a documented RepairCenter Transactional API —
    /// this is the more directly self-serve of the two. Replace clientID and
    /// the endpoint URLs with the real values once you've registered an app
    /// there; these are structured correctly but not real credentials.
    static let mitchell = OAuthProviderConfig(
        name: "Mitchell",
        clientID: "REPLACE_WITH_MITCHELL_CLIENT_ID",
        authorizationEndpoint: URL(string: "https://developer.mitchell.com/oauth/authorize")!,
        tokenEndpoint: URL(string: "https://developer.mitchell.com/oauth/token")!,
        redirectURI: URL(string: "dentdog://oauth/mitchell")!,
        scopes: ["estimate.read", "estimate.write"]
    )

    /// CCC integration goes through their Secure Share marketplace, which
    /// requires active CIECA membership before real credentials are issued.
    /// These endpoints are placeholders — CCC's actual OAuth URLs aren't
    /// public until you're in their partner program.
    static let ccc = OAuthProviderConfig(
        name: "CCC",
        clientID: "REPLACE_WITH_CCC_CLIENT_ID",
        authorizationEndpoint: URL(string: "https://api.cccis.com/oauth/authorize")!,
        tokenEndpoint: URL(string: "https://api.cccis.com/oauth/token")!,
        redirectURI: URL(string: "dentdog://oauth/ccc")!,
        scopes: ["estimate.read", "estimate.write"]
    )
}

/// A stored access/refresh token pair, persisted in Keychain (not
/// UserDefaults — tokens are secrets and don't belong in plist-backed storage).
struct OAuthToken: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    var isExpired: Bool { Date() >= expiresAt }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

/// Minimal Keychain wrapper — tokens are the only thing DentDOG needs to
/// store securely, so this doesn't try to be a general-purpose Keychain library.
enum KeychainStore {
    static func save(_ data: Data, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }
    static func delete(key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class OAuthClient: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    let config: OAuthProviderConfig
    @Published var token: OAuthToken?
    @Published var isAuthenticating = false
    @Published var lastError: String?

    private var codeVerifier = ""
    private var session: ASWebAuthenticationSession?
    private var keychainKey: String { "dentdog.oauth.\(config.name)" }

    var isConnected: Bool { token != nil }

    init(config: OAuthProviderConfig) {
        self.config = config
        super.init()
        loadStoredToken()
    }

    private func loadStoredToken() {
        guard let data = KeychainStore.load(key: keychainKey),
              let saved = try? JSONDecoder().decode(OAuthToken.self, from: data) else { return }
        token = saved
    }

    private func persist(_ token: OAuthToken) {
        self.token = token
        if let data = try? JSONEncoder().encode(token) {
            KeychainStore.save(data, key: keychainKey)
        }
    }

    func signOut() {
        token = nil
        KeychainStore.delete(key: keychainKey)
    }

    // MARK: - PKCE (RFC 7636) — protects the auth code exchange even though
    // a native app can't keep a client secret truly confidential.

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64URLEncodedString()
    }

    private func codeChallenge(for verifier: String) -> String {
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        return Data(hashed).base64URLEncodedString()
    }

    // MARK: - Sign in

    func signIn() {
        codeVerifier = generateCodeVerifier()
        let challenge = codeChallenge(for: codeVerifier)

        var components = URLComponents(url: config.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        guard let authURL = components.url, let scheme = config.redirectURI.scheme else {
            lastError = "Couldn't build the authorization URL."
            return
        }
        isAuthenticating = true

        session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { [weak self] callbackURL, error in
            guard let self else { return }
            self.isAuthenticating = false
            guard let callbackURL, error == nil,
                  let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                      .queryItems?.first(where: { $0.name == "code" })?.value else {
                if let error, (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    self.lastError = error.localizedDescription
                }
                return
            }
            Task { await self.exchangeCodeForToken(code) }
        }
        session?.presentationContextProvider = self
        session?.prefersEphemeralWebBrowserSession = true
        session?.start()
    }

    // MARK: - Token exchange

    private func exchangeCodeForToken(_ code: String) async {
        let params = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI.absoluteString,
            "client_id": config.clientID,
            "code_verifier": codeVerifier,
        ]
        await performTokenRequest(params: params) { [weak self] response in
            self?.persist(OAuthToken(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
            ))
        }
    }

    /// Call this before any API request if `token?.isExpired == true`.
    func refreshIfNeeded() async {
        guard let token, token.isExpired, let refreshToken = token.refreshToken else { return }
        let params = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": config.clientID,
        ]
        await performTokenRequest(params: params) { [weak self] response in
            self?.persist(OAuthToken(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
            ))
        }
    }

    private func performTokenRequest(params: [String: String], onSuccess: @escaping (TokenResponse) -> Void) async {
        var request = URLRequest(url: config.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TokenResponse.self, from: data)
            onSuccess(response)
        } catch {
            lastError = "Token request failed: \(error.localizedDescription)"
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
