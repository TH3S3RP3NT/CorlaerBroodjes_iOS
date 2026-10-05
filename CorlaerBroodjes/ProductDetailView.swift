import SwiftUI

struct ProductDetailView: View {
    @Environment(OrderingStore.self) private var store
    let product: Product

    @State private var addedCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProductImage(urlString: product.imageUrl)

                VStack(spacing: 6) {
                    Text(product.name)
                        .font(.title2.bold())
                    Text(Money.format(cents: product.priceCents))
                        .font(.headline)
                }
                .foregroundStyle(.white)

                if let description = product.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }

                Button {
                    store.add(product)
                    addedCount += 1
                } label: {
                    Text(product.inStock ? "Voeg toe" : "Uitverkocht")
                        .font(.headline)
                        .foregroundStyle(Theme.purple)
                        .padding(.horizontal, 28)
                        .frame(minHeight: 44)
                        .background(.white, in: Capsule())
                }
                .disabled(!product.inStock)
                .opacity(product.inStock ? 1 : 0.6)

                if store.quantity(of: product) > 0 {
                    Text("\(store.quantity(of: product)) in je winkelmandje")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Theme.purple, in: RoundedRectangle(cornerRadius: 20))
            .padding()
        }
        .sensoryFeedback(.success, trigger: addedCount)
        .appChrome()
    }
}
