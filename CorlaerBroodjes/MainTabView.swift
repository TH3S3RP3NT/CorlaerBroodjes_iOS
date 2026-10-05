import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Menu", systemImage: "fork.knife") {
                MenuView()
            }
            Tab("Account", systemImage: "person.crop.circle") {
                AccountView()
            }
        }
    }
}
