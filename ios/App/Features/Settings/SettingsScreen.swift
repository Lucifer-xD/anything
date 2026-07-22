import SwiftUI
import NimbusKit

/// The Settings tab — implements the design's SETTINGS section together with the
/// inline APPEARANCE block (theme preview tiles + accent swatches) and the
/// grouped preference sections (TUNNEL, DNS & ROUTING, LIBRARY, APP). Pushes are
/// routed through a single `navigationDestination` keyed off ``SettingsScreen/Route``
/// (Security, Live Log, Statistics, Servers, and the account/login screen).
struct SettingsScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette

    /// Push targets reachable from Settings.
    enum Route: Hashable {
        case account, security, logs, statistics, servers
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenTitle(title: "Settings")
                    profileCard
                    appearanceBlock
                    tunnelSection
                    dnsSection
                    librarySection
                    appSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 108)
            }
            .background(palette.bg.ignoresSafeArea())
            .toolbar(.hidden)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .account: AccountScreen()
                case .security: SecurityScreen()
                case .logs: LogsScreen()
                case .statistics: StatisticsScreen()
                case .servers: ServersScreen()
                }
            }
        }
    }

    // MARK: - Profile card

    private var accountName: String {
        model.syncAccount?.email ?? "Local library"
    }

    private var accountInitials: String {
        if let email = model.syncAccount?.email {
            let local = email.split(separator: "@").first.map(String.init) ?? email
            let parts = local.split(whereSeparator: { ".-_+".contains($0) })
            let letters = parts.compactMap { $0.first }.prefix(2)
            if !letters.isEmpty { return String(letters).uppercased() }
            return String(local.prefix(2)).uppercased()
        }
        return "LL"
    }

    private var profileCard: some View {
        NavigationLink(value: Route.account) {
            HStack(spacing: 14) {
                Text(accountInitials)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(
                            colors: [palette.accent, Color(hex: "#5E5CE6")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(accountName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    Text("\(model.configs.count) configs · \(model.subscriptions.count) subscriptions")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.text2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text3)
            }
            .padding(16)
            .nimbusCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Appearance

    private var appearanceBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(title: "APPEARANCE")
            HStack(spacing: 10) {
                ForEach(AppTheme.allCases) { theme in
                    themeTile(theme)
                }
            }
            SectionLabel(title: "ACCENT COLOR")
                .padding(.top, 11)
            HStack(spacing: 14) {
                ForEach(AppAccent.allCases) { accent in
                    accentSwatch(accent)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .nimbusCard(cornerRadius: 16, elevated: false)
        }
    }

    private func themeTile(_ theme: AppTheme) -> some View {
        let preview = NimbusPalette(theme: theme, accent: model.accent)
        let selected = model.theme == theme
        return Button {
            model.theme = theme
            haptic()
        } label: {
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        preview.bg
                        Capsule()
                            .fill(preview.accent.opacity(0.9))
                            .frame(width: geo.size.width * 0.6, height: 8)
                            .padding(8)
                    }
                }
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(preview.border, lineWidth: 1)
                )
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(selected ? palette.accent : .clear)
                )
                HStack(spacing: 5) {
                    Text(theme.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? palette.text : palette.text2)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(palette.accent)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func accentSwatch(_ accent: AppAccent) -> some View {
        let selected = model.accent == accent
        return Button {
            model.accent = accent
            haptic()
        } label: {
            Circle()
                .fill(accent.color)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(selected ? 1 : 0)
                )
                .overlay(
                    Circle().strokeBorder(accent.color.opacity(0.35), lineWidth: selected ? 4 : 0)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Setting groups

    private var tunnelSection: some View {
        groupCard("TUNNEL") {
            menuRow(icon: "bolt.horizontal.fill", tint: palette.accent, label: "Default Protocol",
                    value: model.settings.defaultProtocol.metadata.displayName) {
                ForEach(ProtocolKind.allCases) { kind in
                    Button(kind.metadata.displayName) { model.settings.defaultProtocol = kind }
                }
            }
            rowDivider
            toggleRow(icon: "wand.and.stars", tint: palette.success, label: "Auto-Connect",
                      isOn: $model.settings.autoConnect)
            rowDivider
            toggleRow(icon: "hand.raised.fill", tint: palette.danger, label: "Kill Switch",
                      isOn: $model.settings.killSwitch)
            rowDivider
            toggleRow(icon: "arrow.triangle.branch", tint: Color(hex: "#5E5CE6"), label: "Split Tunneling",
                      isOn: $model.settings.splitTunnel)
            rowDivider
            toggleRow(icon: "network", tint: Color(hex: "#64D2FF"), label: "TUN / System Proxy",
                      isOn: $model.settings.tunMode)
        }
    }

    private var dnsSection: some View {
        groupCard("DNS & ROUTING") {
            menuRow(icon: "globe", tint: palette.accent, label: "Custom DNS",
                    value: model.settings.dns.servers.first ?? model.settings.dns.mode.rawValue) {
                ForEach(DNSSettings.presets) { preset in
                    Button(preset.name) { model.settings.dns = preset.settings }
                }
            }
            rowDivider
            toggleRow(icon: "lock.shield.fill", tint: palette.success, label: "DNS over HTTPS",
                      isOn: $model.settings.doh)
            rowDivider
            toggleRow(icon: "6.circle.fill", tint: Color(hex: "#BF5AF2"), label: "IPv6",
                      isOn: $model.settings.ipv6)
        }
    }

    private var librarySection: some View {
        groupCard("LIBRARY") {
            navRow(icon: "text.alignleft", tint: palette.warning, label: "Live Log", route: .logs)
            rowDivider
            navRow(icon: "chart.bar.fill", tint: palette.accent, label: "Statistics", route: .statistics)
            rowDivider
            actionRow(icon: "arrow.up.doc.fill", tint: palette.success, label: "Encrypted Backup") {
                model.backupNow()
                haptic()
            }
            rowDivider
            navRow(icon: "lock.fill", tint: Color(hex: "#5E5CE6"), label: "Security", route: .security)
            rowDivider
            navRow(icon: "server.rack", tint: palette.accent, label: "Servers", route: .servers)
        }
    }

    private var appSection: some View {
        groupCard("APP") {
            toggleRow(icon: "hand.tap.fill", tint: palette.warning, label: "Haptic Feedback",
                      isOn: $model.settings.haptics)
            rowDivider
            menuRow(icon: "character.bubble.fill", tint: palette.accent, label: "Language",
                    value: model.settings.language) {
                ForEach(Self.languages, id: \.self) { lang in
                    Button(lang) { model.settings.language = lang }
                }
            }
        }
    }

    private static let languages = ["English", "Español", "Deutsch", "Français", "日本語", "中文"]

    private var footer: some View {
        Text("Nimbus · 1.0.0")
            .font(.system(size: 12))
            .foregroundStyle(palette.text3)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Group + row builders

    private func groupCard<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: title)
            VStack(spacing: 0) { content() }
                .nimbusCard(cornerRadius: 16, elevated: false)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(palette.divider)
            .frame(height: 1)
            .padding(.leading, 56)
    }

    private func toggleRow(icon: String, tint: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            SettingsIcon(system: icon, tint: tint)
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(palette.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func navRow(icon: String, tint: Color, label: String, route: Route) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                SettingsIcon(system: icon, tint: tint)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func actionRow(icon: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsIcon(system: icon, tint: tint)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func menuRow<MenuContent: View>(
        icon: String, tint: Color, label: String, value: String,
        @ViewBuilder menu: () -> MenuContent
    ) -> some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: 12) {
                SettingsIcon(system: icon, tint: tint)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.text3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Haptics

    private func haptic() {
        guard model.settings.haptics else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

/// The small rounded icon tile shown at the leading edge of every settings row.
private struct SettingsIcon: View {
    let system: String
    let tint: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(tint)
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: system)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

/// A lightweight account / sync sign-in screen pushed from the profile card,
/// mirroring the design's LOGIN section.
private struct AccountScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var passphrase: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BackButton(label: "Settings") { dismiss() }
                    .padding(.bottom, 20)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.accent, Color(hex: "#5E5CE6")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .padding(.bottom, 22)

                Text("Sync your library")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(palette.text)
                Text("Sign in to back up and sync configs across devices — or skip and stay fully local.")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                VStack(spacing: 12) {
                    field(title: "Email") {
                        TextField("you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    field(title: "Password") {
                        SecureField("••••••••••", text: $passphrase)
                            .textContentType(.password)
                    }
                }
                .padding(.top, 24)

                PrimaryButton(title: "Sign In", systemImage: "arrow.right") {
                    model.signIn(email: email, passphrase: passphrase)
                    dismiss()
                }
                .padding(.top, 20)
                .disabled(email.isEmpty || passphrase.isEmpty)
                .opacity(email.isEmpty || passphrase.isEmpty ? 0.5 : 1)

                Button { dismiss() } label: {
                    Text("Use locally without account")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.text2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden)
        .onAppear { if email.isEmpty { email = model.syncAccount?.email ?? "" } }
    }

    private func field<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(palette.text3)
            content()
                .font(.system(size: 16))
                .foregroundStyle(palette.text)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.elev2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border, lineWidth: 1))
    }
}

#if DEBUG
struct SettingsScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        SettingsScreen()
            .environmentObject(model)
            .nimbusPalette(model.palette)
    }
}
#endif
