import SwiftUI

/// Eerdere bestellingen en hun status (FE10).
struct OrdersView: View {
    @Environment(OrderingStore.self) private var store

    var body: some View {
        Group {
            if store.orders.isEmpty {
                ContentUnavailableView(
                    "Nog geen bestellingen",
                    systemImage: "bag",
                    description: Text("Je bestellingen verschijnen hier zodra je een broodje hebt besteld.")
                )
            } else {
                List(store.orders) { order in
                    OrderRow(order: order)
                }
            }
        }
        .refreshable { await store.loadOrders() }
        .task { await store.loadOrders() }
        .appChrome()
    }
}

private struct OrderRow: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bestelling #\(order.id)")
                    .font(.headline)
                Spacer()
                Text(order.status.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.purple.opacity(0.12), in: Capsule())
                    .foregroundStyle(Theme.purple)
            }

            Text("Ophalen: \(order.pickupTime.schoolFormatted())")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(order.items) { item in
                Text("\(item.quantity)× \(item.name) · \(Money.format(cents: item.totalCents))")
                    .font(.subheadline)
            }

            Text("Totaal: \(Money.format(cents: order.totalCents))")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
