import Foundation

/// A lightly-parsed share link (`vless://…`, `ss://…`, `trojan://…`, …).
///
/// Many of these links are *almost* RFC-3986 URLs but contain characters
/// (`+`, unencoded `/`, raw base64) that `URLComponents` rejects, so we parse
/// them defensively by hand and expose the pieces protocol modules need. VMess,
/// whose body is base64-encoded JSON, is handled by its module reading ``body``.
public struct ConfigURI: Equatable, Sendable {
    /// Lowercased scheme without `://` (e.g. `vless`).
    public let scheme: String
    /// The full original string.
    public let raw: String
    /// Everything after `scheme://`.
    public let body: String
    /// userinfo before `@` (uuid, or base64(method:password) for Shadowsocks).
    public let user: String?
    public let host: String?
    public let port: Int?
    /// Path component (leading `/` preserved), if any.
    public let path: String?
    /// `#fragment`, percent-decoded — usually the node's display name.
    public let fragment: String?
    /// Query parameters, percent-decoded.
    public let query: [String: String]

    /// Parses a share link. Returns `nil` if there is no `scheme://` prefix.
    public init?(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let schemeRange = trimmed.range(of: "://") else { return nil }
        raw = trimmed
        scheme = String(trimmed[..<schemeRange.lowerBound]).lowercased()
        var rest = String(trimmed[schemeRange.upperBound...])
        body = rest

        // Fragment
        if let hashIndex = rest.firstIndex(of: "#") {
            fragment = String(rest[rest.index(after: hashIndex)...]).removingPercentEncoding
            rest = String(rest[..<hashIndex])
        } else {
            fragment = nil
        }

        // Query
        var parsedQuery: [String: String] = [:]
        if let qIndex = rest.firstIndex(of: "?") {
            let queryString = String(rest[rest.index(after: qIndex)...])
            rest = String(rest[..<qIndex])
            for pair in queryString.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let value = kv.count > 1 ? (String(kv[1]).removingPercentEncoding ?? String(kv[1])) : ""
                if !key.isEmpty { parsedQuery[key] = value }
            }
        }
        query = parsedQuery

        // userinfo@authority/path
        var authority = rest
        var parsedPath: String?
        if let slashIndex = rest.firstIndex(of: "/") {
            authority = String(rest[..<slashIndex])
            parsedPath = String(rest[slashIndex...])
        }
        path = parsedPath

        var parsedUser: String?
        var hostPort = authority
        if let atIndex = authority.lastIndex(of: "@") {
            parsedUser = String(authority[..<atIndex]).removingPercentEncoding ?? String(authority[..<atIndex])
            hostPort = String(authority[authority.index(after: atIndex)...])
        }
        user = parsedUser

        if let endpoint = Endpoint(hostPort), endpoint.port != 0 {
            host = endpoint.host.isEmpty ? nil : endpoint.host
            port = endpoint.port
        } else if !hostPort.isEmpty {
            host = hostPort
            port = nil
        } else {
            host = nil
            port = nil
        }
    }

    /// Convenience: query value for `key`, non-empty.
    public func query(_ key: String) -> String? {
        guard let value = query[key], !value.isEmpty else { return nil }
        return value
    }
}
