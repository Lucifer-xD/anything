import Foundation

/// How to reconcile a config that changed on two devices.
public enum MergeStrategy: String, CaseIterable, Sendable {
    case newerWins = "Newer wins"
    case preferLocal = "Prefer this device"
    case preferRemote = "Prefer cloud"
}

/// The outcome of merging a local and remote snapshot.
public struct SyncMergeResult: Equatable, Sendable {
    public var merged: StoreSnapshot
    public var addedIDs: [UUID]
    public var updatedIDs: [UUID]
    public var conflictIDs: [UUID]

    public var summary: String {
        "\(addedIDs.count) added · \(updatedIDs.count) updated · \(conflictIDs.count) conflicts"
    }
}

/// Deterministic three-way-ish merge of configuration snapshots. Configs are
/// matched by `id`; conflicts (both sides changed) are resolved by
/// ``MergeStrategy``. Folders and subscriptions merge by id with newer-wins.
public enum ConflictResolver {
    public static func merge(local: StoreSnapshot, remote: StoreSnapshot, strategy: MergeStrategy = .newerWins) -> SyncMergeResult {
        var mergedConfigs: [UUID: TunnelConfiguration] = Dictionary(uniqueKeysWithValues: local.configs.map { ($0.id, $0) })
        var added: [UUID] = []
        var updated: [UUID] = []
        var conflicts: [UUID] = []

        for remoteConfig in remote.configs {
            if let localConfig = mergedConfigs[remoteConfig.id] {
                if localConfig == remoteConfig { continue }
                conflicts.append(remoteConfig.id)
                switch strategy {
                case .preferLocal:
                    break // keep local
                case .preferRemote:
                    mergedConfigs[remoteConfig.id] = remoteConfig
                    updated.append(remoteConfig.id)
                case .newerWins:
                    if remoteConfig.metadata.updatedAt > localConfig.metadata.updatedAt {
                        mergedConfigs[remoteConfig.id] = remoteConfig
                        updated.append(remoteConfig.id)
                    }
                }
            } else {
                mergedConfigs[remoteConfig.id] = remoteConfig
                added.append(remoteConfig.id)
            }
        }

        let folders = mergeByID(local.folders, remote.folders, id: \.id)
        let subs = mergeByID(local.subscriptions, remote.subscriptions, id: \.id)

        // Stable ordering: preserve local order, then appended remote-only items.
        var order = local.configs.map(\.id)
        for id in added where !order.contains(id) { order.insert(id, at: 0) }
        let orderedConfigs = order.compactMap { mergedConfigs[$0] }

        let snapshot = StoreSnapshot(configs: orderedConfigs, folders: folders, subscriptions: subs)
        return SyncMergeResult(merged: snapshot, addedIDs: added, updatedIDs: updated, conflictIDs: conflicts)
    }

    private static func mergeByID<T: Equatable>(_ local: [T], _ remote: [T], id: (T) -> UUID) -> [T] {
        var byID: [UUID: T] = Dictionary(uniqueKeysWithValues: local.map { (id($0), $0) })
        var order = local.map(id)
        for item in remote where byID[id(item)] == nil {
            byID[id(item)] = item
            order.append(id(item))
        }
        return order.compactMap { byID[$0] }
    }
}
