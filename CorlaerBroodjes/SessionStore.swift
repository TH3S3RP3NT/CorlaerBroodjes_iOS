import Foundation
import Observation

/// Houdt bij of de gebruiker is ingelogd en bewaart het app-token in de Keychain.
@Observable
final class SessionStore {
    enum State: Equatable {
        case launching
        case signedOut
        case signedIn(AppUser)
        case unreachable(String)
    }

    private(set) var state: State = .launching
    var isSigningIn = false
    var loginError: String?

    let api = APIClient()
    private let google = GoogleAuth()
    private let keychain = KeychainStore(account: "app-token")

    var user: AppUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    /// Bij het starten: bestaand token controleren bij de server.
    func restore() async {
        guard let token = keychain.read() else {
            state = .signedOut
            return
        }
        api.token = token
        state = .launching
        do {
            state = .signedIn(try await api.me())
        } catch APIError.unauthorized {
            signOut()
        } catch {
            state = .unreachable(error.localizedDescription)
        }
    }

    func signInWithGoogle() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        loginError = nil
        defer { isSigningIn = false }

        do {
            let idToken = try await google.signIn()
            let response = try await api.login(googleIDToken: idToken)
            keychain.save(response.token)
            api.token = response.token
            state = .signedIn(response.user)
        } catch GoogleAuth.Failure.cancelled {
            // De gebruiker sloot het inlogvenster zelf; geen foutmelding nodig.
        } catch {
            loginError = error.localizedDescription
        }
    }

    func signOut() {
        keychain.delete()
        api.token = nil
        state = .signedOut
    }
}
