import Foundation

public extension String {
    /// Decodes standard *or* URL-safe base64, tolerating missing `=` padding —
    /// share links use all of these variants interchangeably.
    func base64DecodedString() -> String? {
        guard let data = base64DecodedData() else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func base64DecodedData() -> Data? {
        var s = trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "-", with: "+")
             .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 { s.append(String(repeating: "=", count: 4 - remainder)) }
        return Data(base64Encoded: s)
    }

    /// URL-safe base64 of the receiver's UTF-8 bytes, no padding.
    func base64URLEncoded() -> String {
        Data(utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

public extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
