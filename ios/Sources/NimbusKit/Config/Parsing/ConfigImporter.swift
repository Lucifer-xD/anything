import Foundation

/// The result of importing raw text: the configurations that parsed, plus a
/// per-line diagnostic so the import-preview screen can show what worked and
/// what didn't.
public struct ImportResult: Equatable, Sendable {
    public var configs: [TunnelConfiguration]
    public var failures: [String]      // human-readable reasons
    public var detectedSource: ConfigSource

    public var isEmpty: Bool { configs.isEmpty }

    public init(configs: [TunnelConfiguration], failures: [String] = [], detectedSource: ConfigSource = .clipboard) {
        self.configs = configs
        self.failures = failures
        self.detectedSource = detectedSource
    }
}

/// Turns arbitrary imported text into configurations. It transparently handles:
///
/// - a **single** share link (`vless://…`),
/// - **many** links separated by newlines,
/// - a **base64 subscription blob** (decodes then splits),
/// - a **WireGuard `.conf`**,
/// - a **Nimbus JSON bundle** (`.nimbus`),
///
/// delegating each link to the owning ``ProtocolModule`` via ``ProtocolRegistry``.
public struct ConfigImporter {
    private let registry: ProtocolRegistry

    public init(registry: ProtocolRegistry = .shared) {
        self.registry = registry
    }

    /// Parse `text` that arrived from `source`.
    public func `import`(_ text: String, source: ConfigSource = .clipboard) -> ImportResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ImportResult(configs: [], failures: ["empty input"], detectedSource: source)
        }

        // 1. Nimbus JSON bundle.
        if trimmed.hasPrefix("{"), let bundle = try? NimbusBundle.decode(from: Data(trimmed.utf8)) {
            return ImportResult(configs: bundle.configs, detectedSource: .file)
        }

        // 2. WireGuard conf.
        if WireGuardConfParser.matches(trimmed) {
            do {
                let config = try WireGuardConfParser.parse(trimmed)
                return ImportResult(configs: [config], detectedSource: .file)
            } catch {
                return ImportResult(configs: [], failures: [Self.reason(error)], detectedSource: source)
            }
        }

        // 3. A base64 subscription blob (no scheme, decodes to link lines).
        if ConfigURI(trimmed) == nil,
           let decoded = trimmed.base64DecodedString(),
           decoded.contains("://") {
            return parseLines(decoded, source: .subscription)
        }

        // 4. One or more share links, newline separated.
        return parseLines(trimmed, source: source)
    }

    private func parseLines(_ text: String, source: ConfigSource) -> ImportResult {
        var configs: [TunnelConfiguration] = []
        var failures: [String] = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            guard let uri = ConfigURI(line) else {
                failures.append("Not a config link: \(line.prefix(32))…")
                continue
            }
            do {
                if let config = try registry.parse(uri) {
                    var stamped = config
                    stamped.metadata.source = source
                    configs.append(stamped)
                } else {
                    failures.append("Unsupported scheme: \(uri.scheme)://")
                }
            } catch {
                failures.append(Self.reason(error))
            }
        }
        return ImportResult(configs: configs, failures: failures, detectedSource: source)
    }

    private static func reason(_ error: Error) -> String {
        (error as? NimbusError)?.errorDescription ?? error.localizedDescription
    }
}
