import SwiftUI
import NimbusKit

/// The dashboard hero card at the top of the Library screen. Implements the
/// three connection states of the HOME · CONFIG LIBRARY design section:
/// a green "connected" summary with the live session timer and throughput,
/// an accent "connecting…" state with a spinner, and an idle quick-connect row.
struct DashboardConnectionCard: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        switch model.connection.bucket {
        case .connected: connected
        case .connecting: connecting
        case .idle: idle
        }
    }

    private var activeName: String { model.activeConfig?.name ?? "No configuration" }

    // MARK: - Connected

    private var connected: some View {
        let config = model.activeConfig
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(palette.success)
                    .frame(width: 8, height: 8)
                    .shadow(color: palette.success, radius: 5)
                Text("CONNECTED")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(palette.success)
                Spacer(minLength: 8)
                Text(ByteFormat.duration(model.elapsedSeconds))
                    .font(.system(size: 22, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(palette.text)
            }

            Text(activeName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .padding(.top, 12)

            if let config {
                Text("\(config.kind.metadata.displayName) · \(config.host):\(config.port)")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)
                    .padding(.top, 2)
            }

            HStack(spacing: 20) {
                throughput(symbol: "↓", value: model.sample.downloadMbps, tint: palette.success)
                throughput(symbol: "↑", value: model.sample.uploadMbps, tint: palette.accent)
                Spacer(minLength: 8)
                Button { model.disconnect() } label: {
                    Text("Disconnect")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.danger)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(palette.danger.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(palette.danger.opacity(0.30), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [palette.success.opacity(0.18), palette.accent.opacity(0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(palette.success.opacity(0.32), lineWidth: 1))
    }

    private func throughput(symbol: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 2) {
            Text(symbol).font(.system(size: 12)).foregroundStyle(palette.text2)
            Text(String(format: "%.1f", value))
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(" Mbps").font(.system(size: 11)).foregroundStyle(palette.text3)
        }
    }

    // MARK: - Connecting

    private var connecting: some View {
        HStack(spacing: 14) {
            SpinnerRing()
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connecting…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(activeName)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(palette.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(palette.accent.opacity(0.28), lineWidth: 1))
    }

    // MARK: - Idle

    private var idle: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(palette.elev2)
                    .frame(width: 46, height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1))
                Image(systemName: "power")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.text2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Not connected")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text("Quick connect · \(activeName)")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button { model.quickConnect() } label: {
                Text("Connect")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .nimbusCard(cornerRadius: 22)
    }
}

/// A lightweight indeterminate ring spinner matching the design's connecting card.
private struct SpinnerRing: View {
    @Environment(\.palette) private var palette
    @State private var spin = false
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.28)
            .stroke(palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .background(Circle().stroke(palette.accent.opacity(0.20), lineWidth: 3))
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin = true }
    }
}
