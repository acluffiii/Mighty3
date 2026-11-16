import Foundation

/// A place someone shared from OvaYonder.
///
/// The link is `https://ovayonder.sunovabit.org/p/?lat=29.7604&lng=-95.3698&name=Downtown%20Houston`.
/// Without the app, it opens a web page with the spot on a map and buttons for Apple Maps and
/// Google Maps. With the app installed, the site's apple-app-site-association file sends `/p/`
/// links to OvaYonder, and `SharedPinLink.pin(from:)` reads them. The web page applies the same
/// rules: decimal degrees in range, and a plain-text name of at most 80 characters.
public struct SharedPin: Equatable, Hashable, Sendable, Identifiable {
    public let coordinate: Coordinate
    /// The cleaned display name, or nil when the link had no usable name.
    public let name: String?

    public init(coordinate: Coordinate, name: String?) {
        self.coordinate = coordinate
        self.name = SharedPinLink.cleanName(name)
    }

    public var id: String { "\(coordinate.latitude),\(coordinate.longitude)|\(name ?? "")" }

    /// The name, or "Shared location" when there isn't one.
    public var title: String { name ?? SharedPinLink.untitled }
}

public enum SharedPinLink {
    public static let untitled = "Shared location"
    public static let maxNameLength = 80

    /// Characters left as-is in a query value. Everything else, including `&`, `=`, `+` and
    /// spaces, is percent-encoded, so any name survives the trip intact.
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    /// The link to text: `https://ovayonder.sunovabit.org/p/?lat=…&lng=…&name=…`.
    public static func webURL(for pin: SharedPin) -> URL {
        var query = "lat=\(degreesText(pin.coordinate.latitude))&lng=\(degreesText(pin.coordinate.longitude))"
        if let name = pin.name, let encoded = name.addingPercentEncoding(withAllowedCharacters: unreserved) {
            query += "&name=\(encoded)"
        }
        return URL(string: "https://\(LiveShareLink.webHost)/p/?\(query)")!
    }

    /// Reads a shared pin from a `https://ovayonder.sunovabit.org/p/?…` link (with or without the
    /// slash after `p`) or from `ovayonder://p?…`. Returns nil for any other link, or when
    /// `lat`/`lng` are missing, not plain decimal numbers, or out of range.
    public static func pin(from url: URL) -> SharedPin? {
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        let isWebLink = (scheme == "https" || scheme == "http") && host == LiveShareLink.webHost && url.path == "/p"
        let isAppLink = scheme == "ovayonder" && host == "p"
        guard isWebLink || isAppLink else { return nil }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQueryItems ?? []
        func value(_ key: String) -> String? {
            // Read the way a browser does: "+" is a space, then percent-escapes are decoded.
            items.first { $0.name == key }?.value?
                .replacingOccurrences(of: "+", with: " ")
                .removingPercentEncoding
        }
        guard let latitude = degrees(value("lat"), limit: 90),
              let longitude = degrees(value("lng"), limit: 180) else { return nil }
        return SharedPin(coordinate: Coordinate(latitude: latitude, longitude: longitude), name: value("name"))
    }

    /// Plain decimal degrees only: an optional sign, digits, and at most one decimal point.
    /// Rejects exponents, hex, "Infinity", "NaN" and empty text, then checks the range.
    static func degrees(_ text: String?, limit: Double) -> Double? {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        var body = Substring(text)
        if body.first == "-" || body.first == "+" { body = body.dropFirst() }
        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        let isDigit: (Character) -> Bool = { ("0"..."9").contains($0) }
        guard parts.count <= 2,
              parts.allSatisfy({ $0.allSatisfy(isDigit) }),
              parts.contains(where: { !$0.isEmpty }),
              let value = Double(text),
              value.isFinite,
              abs(value) <= limit else { return nil }
        return value
    }

    /// Trims, turns control and invisible formatting characters into spaces, collapses
    /// whitespace, and caps the name at 80 characters (79 plus "…"). Empty becomes nil.
    static func cleanName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var scalars = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .control, .format, .lineSeparator, .paragraphSeparator:
                scalars.append(" ")
            default:
                scalars.append(scalar)
            }
        }
        let collapsed = String(scalars).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        guard collapsed.count > maxNameLength else { return collapsed }
        return String(collapsed.prefix(maxNameLength - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Six decimal places (about 10 cm), without a trailing run of zeros.
    static func degreesText(_ value: Double) -> String {
        var text = String(format: "%.6f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text == "-0" ? "0" : text
    }
}
