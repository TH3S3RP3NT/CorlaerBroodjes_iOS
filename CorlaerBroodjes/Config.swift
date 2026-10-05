import Foundation

enum Config {
    /// Basis-URL van de webapp waar de /api/v1-routes draaien.
    static let apiBaseURL = URL(string: "https://corlaerbroodjes.nl")!

    /// OAuth-client-ID van het type "iOS" uit Google Cloud Console (zelfde project als de webapp).
    /// Het bundle-ID van deze app moet bij die client zijn ingevuld.
    /// Voorbeeld: "1234567890-abcdefg.apps.googleusercontent.com"
    static let googleClientID = "888389775706-2fk9vkhaoak6207dfim2tls79kga88to.apps.googleusercontent.com"

    /// Google eist het omgekeerde client-ID als redirect-schema.
    static var googleRedirectScheme: String {
        googleClientID.split(separator: ".").reversed().joined(separator: ".")
    }

    static var googleRedirectURI: String {
        "\(googleRedirectScheme):/oauth2redirect"
    }
}
