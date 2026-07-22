import Foundation

/// Serializes configurations back out — as share links (for QR / clipboard /
/// share sheet) or as a `.nimbus` bundle (for file/cloud backup).
public struct ConfigExporter {
    private let registry: ProtocolRegistry
    public init(registry: ProtocolRegistry = .shared) { self.registry = registry }

    /// A share link for a single config, if its protocol supports one.
    public func shareLink(for config: TunnelConfiguration) -> String? {
        registry.module(for: config.kind).exportURI(config)
    }

    /// A base64 subscription blob of all share-linkable configs (the inverse of
    /// importing a subscription).
    public func subscriptionBlob(for configs: [TunnelConfiguration]) -> String {
        let links = configs.compactMap { shareLink(for: $0) }
        return Data(links.joined(separator: "\n").utf8).base64EncodedString()
    }

    /// The string to encode into a QR code for `config` — its share link, or a
    /// compact single-config bundle when no link form exists.
    public func qrPayload(for config: TunnelConfiguration) throws -> String {
        if let link = shareLink(for: config) { return link }
        let bundle = NimbusBundle(configs: [config])
        return "nimbus://import?bundle=" + (try bundle.encoded()).base64URLEncoded()
    }

    /// A full `.nimbus` bundle for the given configs and folders.
    public func bundle(configs: [TunnelConfiguration], folders: [ConfigFolder] = [], at date: Date = Date()) throws -> Data {
        try NimbusBundle(exportedAt: date, configs: configs, folders: folders).encoded()
    }
}
