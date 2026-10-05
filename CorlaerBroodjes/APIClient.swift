import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case server(status: Int, code: String, message: String)
    case network
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Je sessie is verlopen. Log opnieuw in."
        case .server(_, _, let message):
            message
        case .network:
            "Geen verbinding met de server. Controleer je internet en probeer het opnieuw."
        case .invalidResponse:
            "Er kwam een onverwacht antwoord van de server. Probeer het later opnieuw."
        }
    }

    var code: String? {
        if case .server(_, let code, _) = self { return code }
        return nil
    }
}

/// Praat met de JSON-API van de webapp (/api/v1).
final class APIClient {
    var token: String?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Ongeldige datum: \(string)")
        }
        return decoder
    }()

    // MARK: - Endpoints

    func login(googleIDToken: String) async throws -> LoginResponse {
        try await send("POST", "api/v1/auth/google", body: ["idToken": googleIDToken], authenticated: false)
    }

    func me() async throws -> AppUser {
        let envelope: UserEnvelope = try await send("GET", "api/v1/me")
        return envelope.user
    }

    func config() async throws -> AppConfig {
        try await send("GET", "api/v1/config")
    }

    func products() async throws -> [Product] {
        let envelope: ProductsEnvelope = try await send("GET", "api/v1/products")
        return envelope.products
    }

    func orders() async throws -> [Order] {
        let envelope: OrdersEnvelope = try await send("GET", "api/v1/orders")
        return envelope.orders
    }

    func createOrder(_ request: CreateOrderRequest) async throws -> Order {
        let envelope: OrderEnvelope = try await send("POST", "api/v1/orders", body: request)
        return envelope.order
    }

    func pay(orderID: Int) async throws -> Order {
        let envelope: OrderEnvelope = try await send("POST", "api/v1/orders/\(orderID)/pay")
        return envelope.order
    }

    func cancel(orderID: Int) async throws {
        let _: OKEnvelope = try await send("DELETE", "api/v1/orders/\(orderID)")
    }

    // MARK: - Transport

    private func send<T: Decodable>(
        _ method: String,
        _ path: String,
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        var request = URLRequest(url: Config.apiBaseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 && authenticated {
                throw APIError.unauthorized
            }
            let envelope = try? decoder.decode(ErrorEnvelope.self, from: data)
            throw APIError.server(
                status: http.statusCode,
                code: envelope?.error.code ?? "onbekend",
                message: envelope?.error.message ?? "Er ging iets mis (\(http.statusCode))."
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }
}
