import SwiftUI

struct CartView: View {
    @Environment(OrderingStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Group {
            if store.cartLines.isEmpty {
                ContentUnavailableView(
                    "Je winkelmandje is leeg",
                    systemImage: "cart",
                    description: Text("Kies een broodje in het menu.")
                )
            } else {
                List {
                    Section("Winkelmandje") {
                        ForEach(store.cartLines) { line in
                            CartRow(line: line)
                        }
                        .onDelete { offsets in
                            let lines = store.cartLines
                            for offset in offsets {
                                store.remove(lines[offset].product)
                            }
                        }
                    }

                    if let config = store.config {
                        Section("Ophalen") {
                            Picker("Pauze", selection: $store.selectedBreak) {
                                ForEach(config.breaks) { slot in
                                    Text("\(slot.name) · \(slot.start)").tag(Optional(slot.index))
                                }
                            }
                            Picker("Locatie", selection: $store.selectedLocationID) {
                                ForEach(config.locations) { location in
                                    Text(location.name).tag(Optional(location.id))
                                }
                            }
                        }
                    }

                    Section {
                        HStack {
                            Text("Totaal")
                                .font(.headline)
                            Spacer()
                            Text(Money.format(cents: store.totalCents))
                                .font(.headline)
                        }
                        .accessibilityElement(children: .combine)

                        if let error = store.checkoutError {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Foutmelding: \(error)")
                        }

                        Button {
                            Task { await store.checkout() }
                        } label: {
                            HStack {
                                if store.isPlacingOrder {
                                    ProgressView().tint(.white)
                                }
                                Text("Betaal")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.black)
                        .disabled(store.isPlacingOrder || store.config == nil)
                    }
                }
            }
        }
        .sheet(item: $store.confirmedOrder) { order in
            OrderConfirmationView(order: order)
        }
        .appChrome(showsCart: false)
    }
}

private struct CartRow: View {
    @Environment(OrderingStore.self) private var store
    let line: CartLine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(line.product.name)
                .font(.body.weight(.semibold))

            HStack {
                Stepper(
                    value: Binding(
                        get: { store.quantity(of: line.product) },
                        set: { store.setQuantity($0, for: line.product) }
                    ),
                    in: 1...max(1, min(OrderingStore.maxQuantityPerProduct, line.product.stockQuantity))
                ) {
                    Text("\(line.quantity)×")
                        .monospacedDigit()
                }
                .labelsHidden()

                Text("\(line.quantity)× \(Money.format(cents: line.product.priceCents))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(Money.format(cents: line.totalCents))
                    .font(.body.weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct OrderConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    let order: Order

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("Bestelling geplaatst")
                .font(.title2.bold())

            Text("Bestelling #\(order.id)")
                .font(.headline)

            VStack(spacing: 4) {
                Text("Ophalen: \(order.pickupTime.schoolFormatted())")
                if let location = order.location {
                    Text("Locatie: \(location.name)")
                }
                Text("Totaal: \(Money.format(cents: order.totalCents))")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button("Klaar") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}
