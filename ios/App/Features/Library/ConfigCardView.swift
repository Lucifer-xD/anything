import SwiftUI
import NimbusKit

/// A single configuration row in the Library list. Implements the config card of
/// the HOME · CONFIG LIBRARY design section: protocol chip, name with pin/favorite
/// markers, endpoint subtitle, a round quick-connect button, and a chip row of
/// protocol / transport / latency / traffic. A context menu exposes the library
/// intents (favorite, pin, duplicate, delete).
struct ConfigCardView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette

    let config: TunnelConfiguration
    let onTap: () -> Void

    private var isActiveConnected: Bool {
        model.connection.bucket == .connected && model.activeConfigID == config.id
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                header
                chipRow
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nimbusCard()
        }
        .buttonStyle(.plain)
        .contextMenu { contextMenu }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            ProtocolChip(kind: config.kind, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(config.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    if config.metadata.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.accent)
                    }
                    if config.metadata.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#FFD60A"))
                    }
                }
                Text("\(config.host):\(config.port) · \(config.metadata.group)")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            quickConnectButton
        }
    }

    private var quickConnectButton: some View {
        Button { model.toggle(config.id) } label: {
            Image(systemName: "power")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isActiveConnected ? palette.success : palette.text2)
                .frame(width: 38, height: 38)
                .background((isActiveConnected ? palette.success : palette.text2).opacity(0.14))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(
                    isActiveConnected ? palette.success.opacity(0.4) : palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chip row

    private var chipRow: some View {
        HStack(spacing: 7) {
            TagChip(text: config.kind.metadata.displayName, tint: config.kind.tint)
            TagChip(text: config.transportLabel)
            LatencyPill(milliseconds: config.metadata.latencyMillis)
            TagChip(text: ByteFormat.short(config.metadata.trafficBytes))
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenu: some View {
        Button {
            model.setFavorite(config.id, !config.metadata.isFavorite)
        } label: {
            Label(config.metadata.isFavorite ? "Unfavorite" : "Favorite",
                  systemImage: config.metadata.isFavorite ? "star.slash" : "star")
        }
        Button {
            model.setPinned(config.id, !config.metadata.isPinned)
        } label: {
            Label(config.metadata.isPinned ? "Unpin" : "Pin",
                  systemImage: config.metadata.isPinned ? "pin.slash" : "pin")
        }
        Button {
            model.duplicate(config.id)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        Divider()
        Button(role: .destructive) {
            model.delete(config.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
