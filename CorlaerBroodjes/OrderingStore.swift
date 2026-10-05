import Foundation
import Observation

/// Menu, winkelmandje, afrekenen en bestelgeschiedenis.
@Observable
final class OrderingStore {
    static let maxQuantityPerProduct = 10

    // Gegevens van de server
    private(set) var products: [Product] = []
    private(set) var config: AppConfig?
    private(set) var orders: [Order] = []

    // Winkelmandje: productId -> aantal
    private(set) var cart: [Int: Int] = [:]
    var selectedBreak: Int?
    var selectedLocationID: Int?

    // Status voor de schermen
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var isPlacingOrder = false
    var checkoutError: String?
    var confirmedOrder: Order?

    private let api: APIClient
    private let onUnauthorized: () -> Void
    /// Verschil tussen servertijd en toesteltijd, zodat de timer klopt als de klok afwijkt.
    private var clockSkew: TimeInterval = 0

    init(api: APIClient, onUnauthorized: @escaping () -> Void) {
        self.api = api
        self.onUnauthorized = onUnauthorized
    }

    // MARK: - Laden

    func loadMenu() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let loadedProducts = try await api.products()
            let loadedConfig = try await api.config()
            products = loadedProducts
            config = loadedConfig
            clockSkew = loadedConfig.serverTime.timeIntervalSince(Date())
            pruneCart()
            applyDefaultSelections()
        } catch {
            loadError = message(for: error)
        }
    }

    func loadOrders() async {
        do {
            orders = try await api.orders()
        } catch {
            _ = message(for: error)
        }
    }

    func reset() {
        products = []
        config = nil
        orders = []
        cart = [:]
        selectedBreak = nil
        selectedLocationID = nil
        loadError = nil
        checkoutError = nil
        confirmedOrder = nil
    }

    // MARK: - Winkelmandje

    var cartLines: [CartLine] {
        products.compactMap { product in
            guard let quantity = cart[product.id], quantity > 0 else { return nil }
            return CartLine(product: product, quantity: quantity)
        }
    }

    var itemCount: Int { cart.values.reduce(0, +) }
    var totalCents: Int { cartLines.reduce(0) { $0 + $1.totalCents } }

    func quantity(of product: Product) -> Int { cart[product.id] ?? 0 }

    func add(_ product: Product) {
        guard product.inStock else { return }
        setQuantity(quantity(of: product) + 1, for: product)
    }

    func setQuantity(_ quantity: Int, for product: Product) {
        let limit = min(Self.maxQuantityPerProduct, max(product.stockQuantity, 0))
        let clamped = min(max(quantity, 0), limit)
        if clamped == 0 {
            cart[product.id] = nil
        } else {
            cart[product.id] = clamped
        }
    }

    func remove(_ product: Product) {
        cart[product.id] = nil
    }

    private func pruneCart() {
        let available = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        for (productID, quantity) in cart {
            guard let product = available[productID], product.inStock else {
                cart[productID] = nil
                continue
            }
            cart[productID] = min(quantity, Self.maxQuantityPerProduct, product.stockQuantity)
        }
    }

    // MARK: - Pauzes en timer

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: config?.timeZone ?? "Europe/Amsterdam") ?? .current
        return calendar
    }

    private func breakStart(_ slot: BreakSlot, on day: Date) -> Date? {
        let parts = slot.start.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }

    /// De eerstvolgende pauze waarvoor nog besteld kan worden, met het aantal seconden tot het
    /// bestelvenster sluit (pauzestart min de ingestelde voorlooptijd).
    func nextOpenBreak(at now: Date) -> (slot: BreakSlot, secondsLeft: TimeInterval)? {
        guard let config else { return nil }
        let corrected = now.addingTimeInterval(clockSkew)
        for slot in config.breaks {
            guard let start = breakStart(slot, on: corrected) else { continue }
            let deadline = start.addingTimeInterval(-Double(config.orderLeadMinutes) * 60)
            if deadline > corrected {
                return (slot, deadline.timeIntervalSince(corrected))
            }
        }
        return nil
    }

    private func applyDefaultSelections() {
        guard let config else { return }
        if let selected = selectedBreak, !config.breaks.contains(where: { $0.index == selected }) {
            selectedBreak = nil
        }
        if selectedBreak == nil {
            selectedBreak = nextOpenBreak(at: Date())?.slot.index ?? config.breaks.first?.index
        }
        if let selected = selectedLocationID, !config.locations.contains(where: { $0.id == selected }) {
            selectedLocationID = nil
        }
        if selectedLocationID == nil {
            selectedLocationID = config.locations.first?.id
        }
    }

    // MARK: - Afrekenen

    /// Plaatst de bestelling en rondt de betaling af. Zolang online betalen nog niet beschikbaar
    /// is, wordt de bestelling weer geannuleerd zodat de voorraad vrijkomt.
    func checkout() async {
        guard !cartLines.isEmpty else { return }
        guard let locationID = selectedLocationID, let pickupBreak = selectedBreak else {
            checkoutError = "Kies een ophaallocatie en een pauze."
            return
        }

        isPlacingOrder = true
        checkoutError = nil
        defer { isPlacingOrder = false }

        var placed: Order?
        do {
            let request = CreateOrderRequest(
                locationId: locationID,
                pickupBreak: pickupBreak,
                items: cartLines.map { .init(productId: $0.product.id, quantity: $0.quantity) }
            )
            let order = try await api.createOrder(request)
            placed = order
            confirmedOrder = try await api.pay(orderID: order.id)
            cart = [:]
            await loadOrders()
            await loadMenu()
        } catch {
            if let placed {
                try? await api.cancel(orderID: placed.id)
            }
            checkoutError = message(for: error)
            await loadOrders()
        }
    }

    // MARK: - Fouten

    private func message(for error: Error) -> String {
        if case APIError.unauthorized = error {
            onUnauthorized()
        }
        return error.localizedDescription
    }
}
