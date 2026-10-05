import SwiftUI

/// Gedeelde kop van de schermen: titel, winkelmandknop en de Pauze Bestel-Timer.
struct AppChrome: ViewModifier {
    @Environment(OrderingStore.self) private var store
    let showsCart: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Corlaer Broodjes")
                        .font(.headline)
                        .foregroundStyle(Theme.purple)
                }
                if showsCart {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            CartView()
                        } label: {
                            Image(systemName: "cart")
                                .overlay(alignment: .topTrailing) {
                                    if store.itemCount > 0 {
                                        Text("\(store.itemCount)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(4)
                                            .background(Theme.purple, in: Circle())
                                            .offset(x: 10, y: -10)
                                    }
                                }
                        }
                        .accessibilityLabel("Winkelmandje, \(store.itemCount) producten")
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                BreakTimerBar()
            }
    }
}

extension View {
    func appChrome(showsCart: Bool = true) -> some View {
        modifier(AppChrome(showsCart: showsCart))
    }
}

/// "Pauze Bestel-Timer: Nog 9:51 voor 1e pauze"
struct BreakTimerBar: View {
    @Environment(OrderingStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack {
                Text("Pauze Bestel-Timer:")
                    .font(.subheadline.bold())
                Spacer()
                Text(label(at: context.date))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(Theme.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white, in: Capsule())
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(Theme.purple)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private func label(at date: Date) -> String {
        guard store.config != nil else { return "Laden…" }
        guard let next = store.nextOpenBreak(at: date) else { return "Bestellen gesloten" }

        let total = max(Int(next.secondsLeft), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        let time = hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
        return "Nog \(time) voor \(next.slot.name)"
    }
}
