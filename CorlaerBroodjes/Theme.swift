import SwiftUI

enum Theme {
    /// Paars uit de schermontwerpen (#852975).
    static let purple = Color(red: 133 / 255, green: 41 / 255, blue: 117 / 255)
}

enum Money {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter
    }()

    static func format(cents: Int) -> String {
        formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "€\(cents / 100)"
    }
}

extension Date {
    /// Datum en tijd in Nederlandse tijd, ongeacht de tijdzone van het toestel.
    func schoolFormatted() -> String {
        let style = Date.FormatStyle(
            date: .abbreviated,
            time: .shortened,
            locale: Locale(identifier: "nl_NL"),
            timeZone: TimeZone(identifier: "Europe/Amsterdam") ?? .current
        )
        return formatted(style)
    }
}
