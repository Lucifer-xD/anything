import Foundation

public extension CharacterSet {
    /// Characters allowed *inside a query value* — alphanumerics plus the RFC-3986
    /// unreserved marks. Unlike `.urlQueryAllowed`, this deliberately excludes
    /// `&`, `=`, `?`, `/` and `+` so exported share links round-trip cleanly.
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
