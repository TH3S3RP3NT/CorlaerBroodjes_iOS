import SwiftUI

struct AccountView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        NavigationStack {
            List {
                if let user = session.user {
                    Section {
                        LabeledContent("ID", value: user.id)
                        LabeledContent("Naam", value: user.name)
                        LabeledContent("E-mail", value: user.email)
                        LabeledContent("Rol", value: user.role)
                    }
                }

                Section {
                    NavigationLink {
                        OrdersView()
                    } label: {
                        Label("Mijn bestellingen", systemImage: "list.bullet.rectangle")
                    }
                }

                Section {
                    Button("Uitloggen", role: .destructive) {
                        session.signOut()
                    }
                }
            }
            .appChrome()
        }
    }
}
