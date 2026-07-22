import Foundation

/// The portable export/backup format (`.nimbus`). A versioned JSON envelope of
/// configurations and folders. Used for file export, share sheets, and — once
/// encrypted — cloud backup.
public struct NimbusBundle: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var appVersion: String
    public var configs: [TunnelConfiguration]
    public var folders: [ConfigFolder]

    public init(
        version: Int = NimbusBundle.currentVersion,
        exportedAt: Date = Date(),
        appVersion: String = "1.0.0",
        configs: [TunnelConfiguration],
        folders: [ConfigFolder] = []
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.configs = configs
        self.folders = folders
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public func encoded() throws -> Data {
        do { return try Self.encoder().encode(self) }
        catch { throw NimbusError.storage(reason: "failed to encode bundle: \(error)") }
    }

    public static func decode(from data: Data) throws -> NimbusBundle {
        do { return try decoder().decode(NimbusBundle.self, from: data) }
        catch { throw NimbusError.storage(reason: "failed to decode bundle: \(error)") }
    }
}
