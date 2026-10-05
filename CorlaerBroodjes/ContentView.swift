import SwiftUI

/// Hoofdscherm: kiest tussen laden, inloggen, de app zelf en een foutmelding bij geen verbinding.
struct ContentView: View {
    @Environment(SessionStore.self) private var session
    @Environment(OrderingStore.self) private var ordering

    var body: some View {
        Group {
            switch session.state {
            case .launching:
                ProgressView("Laden…")
            case .signedOut:
                LoginView()
            case .signedIn:
                MainTabView()
            case .unreachable(let message):
                ContentUnavailableView {
                    Label("Geen verbinding", systemImage: "wifi.slash")
                } description: {
                    Text(message)
                } actions: {
                    Button("Opnieuw proberen") {
                        Task { await session.restore() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task { await session.restore() }
        .onChange(of: session.state) { _, newState in
            if newState == .signedOut {
                ordering.reset()
            }
        }
    }
}

#Preview {
    let session = SessionStore()
    return ContentView()
        .environment(session)
        .environment(OrderingStore(api: session.api, onUnauthorized: {}))
}
