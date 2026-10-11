import Foundation
import Observation

nonisolated struct OAuthTokens: Codable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

enum AuthError: LocalizedError {
    case missingClientCredentials
    case notSignedIn
    case sessionExpired
    case invalidRedirect
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingClientCredentials:
            String(localized: "Client ID/secret not found in the Keychain (breeze-client-id / breeze-client-secret).")
        case .notSignedIn:
            String(localized: "Connect your SmartThings account.")
        case .sessionExpired:
            String(localized: "Your SmartThings session expired. Please connect again.")
        case .invalidRedirect:
            String(localized: "The login response doesn't match this request. Try connecting again.")
        case .server(let message):
            String(localized: "Authentication error: \(message)")
        }
    }
}

// OAuth login for the app created with `smartthings apps:create`.
// Access tokens last 24 hours. A new refresh token comes with every refresh.
@Observable
final class AuthManager {
    enum State { case signedOut, signedIn }

    static let redirectURI = "https://httpbin.org/get"
    static let redirectHost = "httpbin.org"
    private static let scopes = "r:devices:* x:devices:* r:locations:*"
    private static let authorizeURL = "https://api.smartthings.com/oauth/authorize"
    private static let tokenURL = URL(string: "https://auth-global.api.smartthings.com/oauth/token")!
    private static let tokenService = "breeze-oauth"
    private static let tokenAccount = "tokens"

    private(set) var state: State {
        didSet { if state != oldValue { onStateChange?(state) } }
    }
    @ObservationIgnored var onStateChange: ((State) -> Void)?
    private var tokens: OAuthTokens?
    private var refreshTask: Task<OAuthTokens, Error>?
    private var credentials: (id: String, secret: String)?
    // Random value sent with the login request and checked on the way back.
    private var pendingState: String?

    init() {
        if let data = Keychain.read(service: Self.tokenService, account: Self.tokenAccount),
           let saved = try? JSONDecoder().decode(OAuthTokens.self, from: data) {
            tokens = saved
            state = .signedIn
        } else {
            state = .signedOut
        }
    }

    func authorizationURL() throws -> URL {
        let creds = try clientCredentials()
        let state = UUID().uuidString
        pendingState = state
        var components = URLComponents(string: Self.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: creds.id),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }

    // Handles `https://httpbin.org/get?code=…&state=…`.
    func handleRedirect(_ url: URL) async throws {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let state = items.first { $0.name == "state" }?.value
        guard let pendingState, state == pendingState,
              let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty
        else { throw AuthError.invalidRedirect }
        self.pendingState = nil
        try await exchange(code: code)
    }

    private func exchange(code: String) async throws {
        let creds = try clientCredentials()
        let tokens = try await requestTokens([
            "grant_type": "authorization_code",
            "code": code,
            "client_id": creds.id,
            "redirect_uri": Self.redirectURI,
        ], credentials: creds)
        save(tokens)
    }

    func accessToken(forceRefresh: Bool = false) async throws -> String {
        guard let tokens else { throw AuthError.notSignedIn }
        if !forceRefresh, tokens.expiresAt.timeIntervalSinceNow > 300 {
            return tokens.accessToken
        }
        return try await refresh().accessToken
    }

    func signOut() {
        tokens = nil
        Keychain.delete(service: Self.tokenService, account: Self.tokenAccount)
        state = .signedOut
    }

    // MARK: - Private

    // If many requests need a new token at the same time, they all wait for the same refresh.
    private func refresh() async throws -> OAuthTokens {
        if let refreshTask { return try await refreshTask.value }
        guard let current = tokens else { throw AuthError.notSignedIn }

        let task = Task {
            let creds = try clientCredentials()
            return try await requestTokens([
                "grant_type": "refresh_token",
                "refresh_token": current.refreshToken,
                "client_id": creds.id,
            ], credentials: creds)
        }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            let fresh = try await task.value
            save(fresh)
            return fresh
        } catch AuthError.sessionExpired {
            signOut()
            throw AuthError.sessionExpired
        }
    }

    private func save(_ tokens: OAuthTokens) {
        self.tokens = tokens
        if let data = try? JSONEncoder().encode(tokens) {
            Keychain.write(data, service: Self.tokenService, account: Self.tokenAccount)
        }
        state = .signedIn
    }

    private func clientCredentials() throws -> (id: String, secret: String) {
        if let credentials { return credentials }
        let account = NSUserName()
        guard let id = Keychain.readString(service: "breeze-client-id", account: account),
              let secret = Keychain.readString(service: "breeze-client-secret", account: account)
        else { throw AuthError.missingClientCredentials }
        credentials = (id, secret)
        return (id, secret)
    }

    private func requestTokens(_ params: [String: String], credentials: (id: String, secret: String)) async throws -> OAuthTokens {
        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        let basic = Data("\(credentials.id):\(credentials.secret)".utf8).base64EncodedString()
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(Self.formEncode(params).utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let body = String(decoding: data, as: UTF8.self)
            if body.contains("invalid_grant") { throw AuthError.sessionExpired }
            throw AuthError.server("HTTP \(status) \(body.prefix(200))")
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return OAuthTokens(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: Date().addingTimeInterval(decoded.expires_in)
        )
    }

    private static func formEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)" }
            .joined(separator: "&")
    }
}

private nonisolated struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Double
}
