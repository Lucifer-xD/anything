import Foundation

/// Persists the store snapshot to a single JSON file, written atomically. In the
/// app this lives in the shared app-group container so both the app and the
/// Packet Tunnel extension can read it.
public struct FilePersistence: ConfigPersisting {
    private let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL) {
        self.url = url
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        self.encoder = e
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    /// Convenience initializer pointing at a file named `store.json` inside a
    /// directory, creating the directory if needed.
    public init(directory: URL, filename: String = "store.json") {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.init(url: directory.appendingPathComponent(filename))
    }

    public func load() throws -> StoreSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(StoreSnapshot.self, from: data)
        } catch {
            throw NimbusError.storage(reason: "load failed: \(error)")
        }
    }

    public func persist(_ snapshot: StoreSnapshot) throws {
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            throw NimbusError.storage(reason: "persist failed: \(error)")
        }
    }
}
