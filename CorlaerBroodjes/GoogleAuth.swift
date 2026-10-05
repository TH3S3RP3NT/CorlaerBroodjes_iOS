import AuthenticationServices
import CryptoKit
import UIKit

/// Inloggen met Google via OAuth 2.0 + PKCE in een ASWebAuthenticationSession.
/// Er is geen extra pakket nodig. Het resulterende Google ID-token gaat naar de eigen API
/// (POST /api/v1/auth/google), die het controleert en een app-token teruggeeft.
final class GoogleAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    enum Failure: LocalizedError {
        case cancelled
        case failed

        var errorDescription: String? {
            switch self {
            case .cancelled: nil
            case .failed: "Inloggen met Google is mislukt. Probeer het opnieuw."
            }
        }
    }

    private var session: ASWebAuthenticationSession?

    func signIn() async throws -> String {
        let verifier = Self.randomString(byteCount: 48)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.randomString(byteCount: 16)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Config.googleClientID),
            URLQueryItem(name: "redirect_uri", value: Config.googleRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]

        let callbackURL = try await authenticate(url: components.url!)
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []

        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else {
            throw Failure.failed
        }
        return try await exchange(code: code, verifier: verifier)
    }

    // MARK: - Browsersessie

    private func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Config.googleRedirectScheme
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    continuation.resume(throwing: Failure.cancelled)
                } else {
                    continuation.resume(throwing: Failure.failed)
                }
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                continuation.resume(throwing: Failure.failed)
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        if let window = windowScene?.windows.first(where: \.isKeyWindow) ?? windowScene?.windows.first {
            return window
        }

        if let windowScene = windowScene {
            return UIWindow(windowScene: windowScene)
        }

        fatalError("Geen actieve UIWindowScene gevonden voor ASPresentationAnchor")
    }

    // MARK: - Code omwisselen voor ID-token

    private struct TokenResponse: Decodable {
        let idToken: String

        enum CodingKeys: String, CodingKey {
            case idToken = "id_token"
        }
    }

    private func exchange(code: String, verifier: String) async throws -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        func encode(_ value: String) -> String {
            value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        }

        let fields = [
            "code": code,
            "client_id": Config.googleClientID,
            "code_verifier": verifier,
            "redirect_uri": Config.googleRedirectURI,
            "grant_type": "authorization_code",
        ]

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { "\(encode($0.key))=\(encode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.failed }
            return try JSONDecoder().decode(TokenResponse.self, from: data).idToken
        } catch let failure as Failure {
            throw failure
        } catch {
            throw Failure.failed
        }
    }

    // MARK: - Hulpfuncties

    private static func randomString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
