import SwiftUI
import NimbusKit
#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Full-detail inspector for a single ``TunnelConfiguration`` — the design's
/// CONFIG DETAIL section. Shows the protocol header, a big connect/disconnect
/// CTA, a segmented (Overview / Protocol / Network / Stats) run of grouped
/// key/value rows, and a 3-column action grid (Edit, Duplicate, Export QR, Move,
/// Archive, Delete). Edit and QR are presented as sheets defined in this file.
struct ConfigDetailScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    let configID: UUID

    enum DetailTab: String, CaseIterable, Identifiable {
        case overview, proto, network, stats
        var id: String { rawValue }
        var label: String {
            switch self {
            case .overview: return "Overview"
            case .proto: return "Protocol"
            case .network: return "Network"
            case .stats: return "Stats"
            }
        }
    }

    @State private var selectedTab: DetailTab = .overview
    @State private var showEdit = false
    @State private var showQR = false
    @State private var showDeleteConfirm = false

    private var config: TunnelConfiguration? { model.configs.first { $0.id == configID } }

    var body: some View {
        Group {
            if let config {
                content(for: config)
            } else {
                missingState
            }
        }
        .background(palette.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Missing config guard

    private var missingState: some View {
        VStack(spacing: 14) {
            header
            Spacer()
            Image(systemName: "questionmark.folder")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(palette.text3)
            Text("Configuration not found")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.text)
            Text("It may have been deleted or moved.")
                .font(.system(size: 14))
                .foregroundStyle(palette.text2)
            GhostButton(title: "Back to Configs", systemImage: "chevron.left") { dismiss() }
                .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Main content

    private func content(for config: TunnelConfiguration) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .overlay(alignment: .trailing) { headerToggles(for: config) }

                titleRow(for: config)
                    .padding(.top, 4)

                connectCTA(for: config)
                    .padding(.top, 18)

                segmentedControl
                    .padding(.top, 20)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(groups(for: config)) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: group.title)
                            VStack(spacing: 0) {
                                ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                                    if index > 0 { Divider().overlay(palette.divider) }
                                    detailRowView(row)
                                }
                            }
                            .nimbusCard(cornerRadius: 16, elevated: false)
                        }
                    }
                }
                .padding(.top, 16)

                actionGrid(for: config)
                    .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showEdit) {
            EditConfigView(config: config)
                .nimbusPalette(palette)
                .environmentObject(model)
        }
        .sheet(isPresented: $showQR) {
            QRView(payload: model.qrPayload(for: config), name: config.name)
                .nimbusPalette(palette)
        }
        .confirmationDialog(
            "Delete “\(config.name)”?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Configuration", role: .destructive) {
                model.delete(config.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the configuration from your library.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            BackButton(label: "Configs") { dismiss() }
            Spacer()
        }
        .padding(.bottom, 16)
    }

    private func headerToggles(for config: TunnelConfiguration) -> some View {
        HStack(spacing: 18) {
            Button {
                haptic()
                model.setFavorite(config.id, !config.metadata.isFavorite)
            } label: {
                Image(systemName: config.metadata.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(config.metadata.isFavorite ? palette.warning : palette.text3)
            }
            .buttonStyle(.plain)

            Button {
                haptic()
                model.setPinned(config.id, !config.metadata.isPinned)
            } label: {
                Image(systemName: config.metadata.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(config.metadata.isPinned ? palette.accent : palette.text3)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Title row

    private func titleRow(for config: TunnelConfiguration) -> some View {
        HStack(spacing: 14) {
            ProtocolChip(kind: config.kind, size: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Text("\(config.kind.metadata.displayName) · \(config.metadata.group)")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Connect CTA

    private var isThisConfigActive: Bool {
        model.activeConfigID == configID && model.connection.isActive
    }
    private var isThisConfigConnecting: Bool {
        model.activeConfigID == configID && model.connection.bucket == .connecting
    }

    private func connectCTA(for config: TunnelConfiguration) -> some View {
        let active = isThisConfigActive
        let connecting = isThisConfigConnecting
        let title = active ? "Disconnect" : (connecting ? "Connecting…" : "Connect")
        let icon = active ? "stop.fill" : (connecting ? "arrow.triangle.2.circlepath" : "bolt.fill")
        let bg = active ? palette.danger : palette.accent
        let glow = active ? palette.danger.opacity(0.4) : palette.accent.opacity(0.45)

        return Button {
            haptic()
            if active {
                model.disconnect()
            } else if !connecting {
                model.connect(config.id)
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold))
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: glow, radius: 18, x: 0, y: 8)
            .opacity(connecting ? 0.85 : 1)
        }
        .buttonStyle(.plain)
        .disabled(connecting)
    }

    // MARK: - Segmented control

    private var segmentedControl: some View {
        HStack(spacing: 4) {
            ForEach(DetailTab.allCases) { tab in
                let selected = selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
                } label: {
                    Text(tab.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? palette.text : palette.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(selected ? palette.elev1 : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(palette.elev2)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Grouped rows

    private struct DetailRow: Identifiable {
        let id = UUID()
        let key: String
        let value: String
        var color: Color?
    }
    private struct DetailGroup: Identifiable {
        let id = UUID()
        let title: String
        let rows: [DetailRow]
    }

    private func detailRowView(_ row: DetailRow) -> some View {
        HStack(spacing: 12) {
            Text(row.key)
                .font(.system(size: 15))
                .foregroundStyle(palette.text2)
            Spacer(minLength: 12)
            Text(row.value)
                .font(.system(size: 15))
                .monospacedDigit()
                .foregroundStyle(row.color ?? palette.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func groups(for config: TunnelConfiguration) -> [DetailGroup] {
        switch selectedTab {
        case .overview: return overviewGroups(config)
        case .proto: return protocolGroups(config)
        case .network: return networkGroups(config)
        case .stats: return statsGroups(config)
        }
    }

    private func overviewGroups(_ config: TunnelConfiguration) -> [DetailGroup] {
        let m = config.metadata
        let (statusText, statusColor) = statusDescriptor(for: config)
        let tags = m.tags.isEmpty ? "None" : m.tags.joined(separator: ", ")
        return [
            DetailGroup(title: "IDENTITY", rows: [
                DetailRow(key: "Name", value: config.name),
                DetailRow(key: "Group", value: m.group),
                DetailRow(key: "Tags", value: tags),
                DetailRow(key: "Status", value: statusText, color: statusColor),
            ]),
            DetailGroup(title: "ENDPOINT", rows: [
                DetailRow(key: "Server", value: displayValue(config.host)),
                DetailRow(key: "Port", value: "\(config.port)"),
                DetailRow(key: "Country", value: countryValue(for: config)),
                DetailRow(key: "Transport", value: config.transportLabel),
            ]),
        ]
    }

    private func protocolGroups(_ config: TunnelConfiguration) -> [DetailGroup] {
        let f = config.fields
        let tls = f.string(FieldKey.security).map { $0.capitalized } ?? (config.serverName != nil ? "TLS" : "None")
        return [
            DetailGroup(title: "PROTOCOL", rows: [
                DetailRow(key: "Type", value: config.kind.metadata.displayName),
                DetailRow(key: "Transport", value: config.transportLabel),
                DetailRow(key: "TLS", value: tls),
                DetailRow(key: "Flow", value: displayValue(f.string(FieldKey.flow))),
                DetailRow(key: "SNI", value: displayValue(config.serverName)),
                DetailRow(key: "Fingerprint", value: displayValue(f.string(FieldKey.fingerprint))),
            ]),
            DetailGroup(title: "ENCRYPTION", rows: [
                DetailRow(key: "Cipher", value: displayValue(f.string(FieldKey.cipher))),
                DetailRow(key: "ALPN", value: displayValue(f.string(FieldKey.alpn))),
                DetailRow(key: "Core", value: config.kind.core.rawValue.uppercased()),
            ]),
        ]
    }

    private func networkGroups(_ config: TunnelConfiguration) -> [DetailGroup] {
        let f = config.fields
        let s = model.settings
        let dnsValue = f.string(FieldKey.dns) ?? (s.doh ? "DoH (automatic)" : "Automatic")
        let mtu = f.string(FieldKey.mtu) ?? (config.kind == .wireguard ? "1420" : "Auto")
        return [
            DetailGroup(title: "DNS", rows: [
                DetailRow(key: "Resolver", value: dnsValue),
                DetailRow(key: "Mode", value: s.tunMode ? "TUN" : "Packet tunnel"),
                DetailRow(key: "IPv6", value: s.ipv6 ? "Enabled" : "Disabled",
                          color: s.ipv6 ? palette.text : palette.text2),
            ]),
            DetailGroup(title: "ROUTING", rows: [
                DetailRow(key: "Routing", value: s.splitTunnel ? "Split tunnel" : "Full tunnel"),
                DetailRow(key: "MTU", value: mtu),
                DetailRow(key: "Kill switch", value: s.killSwitch ? "On" : "Off",
                          color: s.killSwitch ? palette.success : palette.text2),
            ]),
        ]
    }

    private func statsGroups(_ config: TunnelConfiguration) -> [DetailGroup] {
        let m = config.metadata
        let sessionValue: String
        if isThisConfigActive {
            sessionValue = ByteFormat.short(model.sample.rxBytes &+ model.sample.txBytes)
        } else {
            sessionValue = "—"
        }
        let lastConnected = m.lastConnectedAt.map(relativeDate) ?? "Never"
        let (expiresText, expiresColor) = expiresDescriptor(m.expiresAt)
        return [
            DetailGroup(title: "TRAFFIC", rows: [
                DetailRow(key: "Total", value: ByteFormat.short(m.trafficBytes)),
                DetailRow(key: "This session", value: sessionValue,
                          color: isThisConfigActive ? palette.accent : palette.text2),
                DetailRow(key: "Last connected", value: lastConnected),
                DetailRow(key: "Expires", value: expiresText, color: expiresColor),
            ]),
            DetailGroup(title: "RELIABILITY", rows: [
                DetailRow(key: "Latency", value: m.latencyMillis.map { "\($0) ms" } ?? "—",
                          color: LatencyPill.color(for: m.latencyMillis, palette: palette)),
                DetailRow(key: "Quality", value: qualityLabel(m.latencyMillis, sessions: m.sessionCount)),
                DetailRow(key: "Sessions", value: "\(m.sessionCount)"),
            ]),
        ]
    }

    // MARK: - Action grid

    private func actionGrid(for config: TunnelConfiguration) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10),
                       GridItem(.flexible(), spacing: 10),
                       GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            actionButton(icon: "pencil", label: "Edit", tint: palette.accent) {
                showEdit = true
            }
            actionButton(icon: "doc.on.doc", label: "Duplicate", tint: palette.success) {
                haptic()
                model.duplicate(config.id)
            }
            actionButton(icon: "qrcode", label: "Export QR", tint: Color(hex: "#BF5AF2")) {
                showQR = true
            }

            Menu {
                Button {
                    model.move(config.id, toFolder: nil)
                } label: {
                    Label("No folder", systemImage: "tray")
                }
                ForEach(model.folders) { folder in
                    Button {
                        model.move(config.id, toFolder: folder.id)
                    } label: {
                        Label(folder.name, systemImage: folder.symbol)
                    }
                }
            } label: {
                actionTile(icon: "arrow.right.arrow.left", label: "Move", tint: palette.warning)
            }

            actionButton(icon: "archivebox", label: "Archive", tint: palette.text2) {
                haptic()
                model.setArchived(config.id, true)
                dismiss()
            }
            actionButton(icon: "trash", label: "Delete", tint: palette.danger, destructive: true) {
                showDeleteConfirm = true
            }
        }
    }

    private func actionButton(
        icon: String,
        label: String,
        tint: Color,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionTile(icon: icon, label: label, tint: tint, destructive: destructive)
        }
        .buttonStyle(.plain)
    }

    private func actionTile(
        icon: String,
        label: String,
        tint: Color,
        destructive: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(destructive ? palette.danger : palette.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(destructive ? palette.danger.opacity(0.1) : palette.elev1)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(destructive ? palette.danger.opacity(0.22) : palette.border, lineWidth: 1)
        )
    }

    // MARK: - Value helpers

    private func displayValue(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "—" }
        return value
    }

    private func countryValue(for config: TunnelConfiguration) -> String {
        if let server = model.servers.first(where: { $0.host == config.host }) {
            return "\(server.flagEmoji) \(server.countryCode)"
        }
        return "—"
    }

    private func statusDescriptor(for config: TunnelConfiguration) -> (String, Color) {
        guard model.activeConfigID == config.id else { return ("Idle", palette.text2) }
        switch model.connection.bucket {
        case .connected: return (model.connection.label, palette.success)
        case .connecting: return (model.connection.label, palette.warning)
        case .idle:
            if case .failed = model.connection { return (model.connection.label, palette.danger) }
            return ("Idle", palette.text2)
        }
    }

    private func expiresDescriptor(_ date: Date?) -> (String, Color) {
        guard let date else { return ("Never", palette.text2) }
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return ("Expired", palette.danger) }
        let color: Color = interval < 7 * 86_400 ? palette.warning : palette.text
        return (mediumDate(date), color)
    }

    private func qualityLabel(_ ms: Int?, sessions: Int) -> String {
        guard let ms else { return sessions > 0 ? "Untested" : "—" }
        if ms < 50 { return "Excellent" }
        if ms < 100 { return "Good" }
        return "Fair"
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func mediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func haptic() {
        #if canImport(UIKit)
        if model.settings.haptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}

// MARK: - Edit sheet

/// A lightweight editor sheet that embeds ``ProtocolFormView`` bound to a local,
/// editable copy of the configuration. Saving commits the draft through the model.
struct EditConfigView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var draft: TunnelConfiguration

    init(config: TunnelConfiguration) {
        _draft = State(initialValue: config)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ProtocolChip(kind: draft.kind, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(draft.name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(palette.text)
                                .lineLimit(1)
                            Text(draft.kind.metadata.displayName)
                                .font(.system(size: 13))
                                .foregroundStyle(palette.text2)
                        }
                        Spacer(minLength: 0)
                    }

                    ProtocolFormView(sections: draft.kind.fieldSchema, fields: $draft.fields)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(palette.bg.ignoresSafeArea())
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(palette.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.save(draft.touched(at: Date()))
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.accent)
                }
            }
        }
    }
}

// MARK: - QR sheet

/// Renders a scannable QR code for the configuration's share payload using
/// CoreImage's `CIQRCodeGenerator`. Falls back to the raw payload text when
/// CoreImage/UIKit is unavailable or the payload cannot be generated.
struct QRView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    let payload: String?
    let name: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 20)

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                    qrContent
                        .padding(24)
                }
                .frame(width: 260, height: 260)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                )

                VStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    Text("Scan to import this configuration")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.text2)
                }

                if let payload {
                    Text(payload)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(palette.text3)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .padding(.horizontal, 30)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(palette.bg.ignoresSafeArea())
            .navigationTitle("Export QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
        }
    }

    @ViewBuilder private var qrContent: some View {
        if let payload, let image = Self.makeQR(payload) {
            image
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            VStack(spacing: 10) {
                Image(systemName: "qrcode")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(.black.opacity(0.35))
                Text("Unavailable")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black.opacity(0.4))
            }
        }
    }

    /// Generates a crisp QR ``Image`` from a payload string.
    static func makeQR(_ string: String) -> Image? {
        #if canImport(CoreImage) && canImport(UIKit)
        let data = Data(string.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return Image(uiImage: UIImage(cgImage: cgImage))
        #else
        return nil
        #endif
    }
}

#if DEBUG
struct ConfigDetailScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        let id = SampleData.configurations.first!.id
        return NavigationStack {
            ConfigDetailScreen(configID: id)
        }
        .environmentObject(model)
        .nimbusPalette(model.palette)
    }
}
#endif
