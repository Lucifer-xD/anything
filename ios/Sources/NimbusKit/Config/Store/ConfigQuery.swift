import Foundation

/// A library filter chip (matches the design's "All / Favorites / Pinned / <group>").
public enum LibraryFilter: Equatable, Sendable {
    case all
    case favorites
    case pinned
    case group(String)
    case folder(UUID)
    case tag(String)
    case subscription(UUID)

    public func matches(_ config: TunnelConfiguration, folders: [ConfigFolder]) -> Bool {
        switch self {
        case .all: return true
        case .favorites: return config.metadata.isFavorite
        case .pinned: return config.metadata.isPinned
        case .group(let name): return config.metadata.group == name
        case .folder(let id): return config.metadata.folderID == id
        case .tag(let tag): return config.metadata.tags.contains(tag)
        case .subscription(let id): return config.metadata.subscriptionID == id
        }
    }
}

/// How results are ordered.
public enum ConfigSort: String, CaseIterable, Sendable {
    case recent = "Recently used"
    case name = "Name"
    case latency = "Latency"
    case protocolName = "Protocol"
}

/// A composable search/filter/sort request against the library. `apply` is a
/// pure function so it can be unit-tested without a store.
public struct ConfigQuery: Equatable, Sendable {
    public var searchText: String
    public var filter: LibraryFilter
    public var sort: ConfigSort
    public var includeArchived: Bool

    public init(
        searchText: String = "",
        filter: LibraryFilter = .all,
        sort: ConfigSort = .recent,
        includeArchived: Bool = false
    ) {
        self.searchText = searchText
        self.filter = filter
        self.sort = sort
        self.includeArchived = includeArchived
    }

    public func apply(to configs: [TunnelConfiguration], folders: [ConfigFolder] = []) -> [TunnelConfiguration] {
        let needle = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        var result = configs.filter { config in
            if !includeArchived && config.metadata.isArchived { return false }
            if !filter.matches(config, folders: folders) { return false }
            if needle.isEmpty { return true }
            return Self.searchHaystack(config).contains(needle)
        }

        result.sort { lhs, rhs in
            // Pinned always float to the top regardless of sort.
            if lhs.metadata.isPinned != rhs.metadata.isPinned {
                return lhs.metadata.isPinned && !rhs.metadata.isPinned
            }
            switch sort {
            case .recent:
                let l = lhs.metadata.lastConnectedAt ?? lhs.metadata.updatedAt
                let r = rhs.metadata.lastConnectedAt ?? rhs.metadata.updatedAt
                return l > r
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .latency:
                return (lhs.metadata.latencyMillis ?? .max) < (rhs.metadata.latencyMillis ?? .max)
            case .protocolName:
                return lhs.kind.metadata.displayName < rhs.kind.metadata.displayName
            }
        }
        return result
    }

    private static func searchHaystack(_ config: TunnelConfiguration) -> String {
        var parts = [config.name, config.host, config.kind.metadata.displayName, config.metadata.group]
        parts.append(contentsOf: config.metadata.tags)
        return parts.joined(separator: " ").lowercased()
    }
}
