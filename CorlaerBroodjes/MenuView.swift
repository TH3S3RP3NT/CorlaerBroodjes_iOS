import SwiftUI

struct MenuView: View {
    @Environment(OrderingStore.self) private var store

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let error = store.loadError, store.products.isEmpty {
                    ContentUnavailableView {
                        Label("Menu niet beschikbaar", systemImage: "wifi.slash")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Opnieuw proberen") {
                            Task { await store.loadMenu() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 40)
                } else if store.products.isEmpty && !store.isLoading {
                    ContentUnavailableView(
                        "Nog geen broodjes",
                        systemImage: "fork.knife",
                        description: Text("Er staan op dit moment geen producten in het menu.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.products) { product in
                            NavigationLink(value: product) {
                                ProductCard(product: product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .overlay {
                if store.isLoading && store.products.isEmpty {
                    ProgressView("Menu laden…")
                }
            }
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
            .refreshable { await store.loadMenu() }
            .task {
                if store.products.isEmpty {
                    await store.loadMenu()
                }
            }
            .appChrome()
        }
    }
}

struct ProductImage: View {
    let urlString: String?

    var body: some View {
        Color.white
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let urlString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "fork.knife")
            .font(.largeTitle)
            .foregroundStyle(Theme.purple.opacity(0.35))
    }
}

struct ProductCard: View {
    let product: Product

    var body: some View {
        VStack(spacing: 8) {
            ProductImage(urlString: product.imageUrl)

            Text(product.name)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(Money.format(cents: product.priceCents))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Theme.purple, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            if !product.inStock {
                Text("Uitverkocht")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red, in: Capsule())
                    .padding(8)
            }
        }
        .opacity(product.inStock ? 1 : 0.65)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(product.name), \(Money.format(cents: product.priceCents))\(product.inStock ? "" : ", uitverkocht")"
        )
    }
}
