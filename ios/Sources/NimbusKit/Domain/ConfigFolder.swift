import Foundation

/// A user-defined folder that groups configurations. The library ships four
/// default folders (Personal, Work, Gaming, Subscriptions) but folders are fully
/// user-managed (create / rename / recolor / reorder / delete).
public struct ConfigFolder: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// Accent hex for the folder chip.
    public var colorHex: String
    /// SF Symbol name suggestion for the folder row.
    public var symbol: String
    public var sortIndex: Int

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#0A84FF",
        symbol: String = "folder",
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.symbol = symbol
        self.sortIndex = sortIndex
    }

    /// The default folder set seeded on first launch. Deterministic ids keep
    /// them stable across devices for sync.
    public static let defaults: [ConfigFolder] = [
        ConfigFolder(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!, name: "Personal", colorHex: "#0A84FF", symbol: "person", sortIndex: 0),
        ConfigFolder(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!, name: "Work", colorHex: "#FF9F0A", symbol: "briefcase", sortIndex: 1),
        ConfigFolder(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!, name: "Gaming", colorHex: "#BF5AF2", symbol: "gamecontroller", sortIndex: 2),
        ConfigFolder(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!, name: "Subscriptions", colorHex: "#30D158", symbol: "arrow.triangle.2.circlepath", sortIndex: 3),
    ]
}
