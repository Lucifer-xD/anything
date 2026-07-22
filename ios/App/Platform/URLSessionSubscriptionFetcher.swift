import Foundation
import NimbusKit

/// Production ``SubscriptionFetching`` backed by `URLSession`. Fetches the
/// subscription body and parses the `subscription-userinfo` header for quota /
/// expiry.
struct URLSessionSubscriptionFetcher: SubscriptionFetching {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func fetch(_ url: URL) async throws -> (body: String, userInfo: SubscriptionUserInfo?) {
        var request = URLRequest(url: url)
        request.setValue("Nimbus/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NimbusError.sync(reason: "subscription HTTP error")
        }
        let body = String(decoding: data, as: UTF8.self)
        var userInfo: SubscriptionUserInfo?
        if let header = http.value(forHTTPHeaderField: "subscription-userinfo") {
            userInfo = SubscriptionService.parseUserInfo(header)
        }
        return (body, userInfo)
    }
}
