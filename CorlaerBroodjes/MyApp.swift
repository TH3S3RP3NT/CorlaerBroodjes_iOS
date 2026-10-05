import SwiftUI

@main struct MyApp: App {
    @State private var session: SessionStore
    @State private var ordering: OrderingStore

    init() {
        let session = SessionStore()
        _session = State(initialValue: session)
        _ordering = State(initialValue: OrderingStore(api: session.api, onUnauthorized: { session.signOut() }))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                .environment(ordering)
                .tint(Theme.purple)
        }
    }
}
