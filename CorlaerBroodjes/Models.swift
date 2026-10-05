import Foundation

// De JSON-vormen komen overeen met de /api/v1-routes in de webapp (src/lib/dto.ts).
// Bedragen zijn altijd gehele centen.

struct AppUser: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let role: String
    let avatarUrl: String?
}

struct Product: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let priceCents: Int
    let imageUrl: String?
    let stockQuantity: Int
    let inStock: Bool
    let preparationTimeMinutes: Int
}

struct BreakSlot: Codable, Identifiable, Hashable {
    let index: Int
    let name: String
    /// "HH:MM" in Nederlandse tijd.
    let start: String

    var id: Int { index }
}

struct PickupLocation: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct AppConfig: Codable {
    let timeZone: String
    let serverTime: Date
    let orderLeadMinutes: Int
    let breaks: [BreakSlot]
    let locations: [PickupLocation]
}

enum OrderStatus: String, Codable {
    case pendingPayment = "PENDING_PAYMENT"
    case paid = "PAID"
    case inPreparation = "IN_PREPARATION"
    case ready = "READY"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    case unknown = "UNKNOWN"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = OrderStatus(rawValue: raw) ?? .unknown
    }

    var label: String {
        switch self {
        case .pendingPayment: "Wacht op betaling"
        case .paid: "Betaald"
        case .inPreparation: "In behandeling"
        case .ready: "Klaar om op te halen"
        case .completed: "Afgehaald"
        case .cancelled: "Geannuleerd"
        case .unknown: "Onbekend"
        }
    }
}

struct OrderLine: Codable, Identifiable, Hashable {
    let id: Int
    let productId: Int
    let name: String
    let quantity: Int
    let unitPriceCents: Int

    var totalCents: Int { quantity * unitPriceCents }
}

struct Order: Codable, Identifiable {
    let id: Int
    let status: OrderStatus
    let totalCents: Int
    let pickupTime: Date
    let estimatedWaitTimeMinutes: Int
    let createdAt: Date
    let location: PickupLocation?
    let items: [OrderLine]
}

struct CartLine: Identifiable {
    let product: Product
    let quantity: Int

    var id: Int { product.id }
    var totalCents: Int { product.priceCents * quantity }
}

// MARK: - Verzoeken en antwoorden

struct CreateOrderRequest: Encodable {
    struct Item: Encodable {
        let productId: Int
        let quantity: Int
    }

    let locationId: Int
    let pickupBreak: Int
    let items: [Item]
}

struct LoginResponse: Decodable {
    let token: String
    let expiresAt: Date
    let user: AppUser
}

struct UserEnvelope: Decodable { let user: AppUser }
struct ProductsEnvelope: Decodable { let products: [Product] }
struct OrdersEnvelope: Decodable { let orders: [Order] }
struct OrderEnvelope: Decodable { let order: Order }
struct OKEnvelope: Decodable { let ok: Bool }

struct ErrorEnvelope: Decodable {
    struct Detail: Decodable {
        let code: String
        let message: String
    }

    let error: Detail
}
