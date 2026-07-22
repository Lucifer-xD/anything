import SwiftUI
import NimbusKit

/// The first-run onboarding flow — Splash → 3-page pager → Permissions → Login.
/// Implements the design's SPLASH, ONBOARDING, PERMISSIONS and LOGIN sections.
/// Completing sign-in (or skipping) calls `model.completeOnboarding()`.
struct OnboardingFlow: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette

    /// The four sequential stages of the flow.
    private enum Stage { case splash, onboarding, permissions, login }

    @State private var stage: Stage = .splash

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            switch stage {
            case .splash:
                SplashStage { advance(to: .onboarding) }
            case .onboarding:
                OnboardingPager { advance(to: .permissions) }
            case .permissions:
                PermissionsStage { advance(to: .login) }
            case .login:
                LoginStage(
                    onSignIn: { email, passphrase in
                        model.signIn(email: email, passphrase: passphrase)
                        model.completeOnboarding()
                    },
                    onSkip: { model.completeOnboarding() }
                )
            }
        }
        .transition(.opacity)
    }

    private func advance(to next: Stage) {
        withAnimation(.easeInOut(duration: 0.35)) { stage = next }
    }
}

// MARK: - Shield glyph

/// The Nimbus shield used across the splash / login / permissions headers.
private struct ShieldGlyph: View {
    var lineWidth: CGFloat = 1.6
    var body: some View {
        ShieldShape()
            .stroke(.white, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
    }
}

/// A rounded VPN-style shield outline (matches the design's SVG path).
private struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x / 24 * w, y: rect.minY + y / 24 * h)
        }
        var path = Path()
        path.move(to: p(12, 2))
        path.addLine(to: p(20, 6))
        path.addLine(to: p(20, 11))
        path.addCurve(to: p(12, 22), control1: p(20, 16), control2: p(16.6, 20.3))
        path.addCurve(to: p(4, 11), control1: p(7.4, 20.3), control2: p(4, 16))
        path.addLine(to: p(4, 6))
        path.closeSubpath()
        return path
    }
}

// MARK: - Splash

private struct SplashStage: View {
    @Environment(\.palette) private var palette
    let onStart: () -> Void
    @State private var breathing = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [palette.accent.opacity(0.22), palette.bg],
                center: UnitPoint(x: 0.5, y: 0.32),
                startRadius: 20,
                endRadius: 480
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [palette.accent.opacity(0.4), .clear],
                                center: .center, startRadius: 4, endRadius: 60
                            )
                        )
                        .frame(width: 130, height: 130)
                        .blur(radius: 6)
                        .scaleEffect(breathing ? 1.08 : 0.92)
                        .opacity(breathing ? 1 : 0.75)

                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.55)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .overlay(ShieldGlyph().padding(21))
                        .shadow(color: palette.accent.opacity(0.6), radius: 30, x: 0, y: 18)
                }

                Text("Nimbus")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(palette.text)
            }

            VStack(spacing: 22) {
                Spacer()
                Button(action: onStart) {
                    Text("Get Started")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 40)
                        .background(palette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: palette.accent.opacity(0.5), radius: 20, x: 0, y: 8)
                }
                .buttonStyle(.plain)

                Text("CONFIGURATION CLIENT")
                    .font(.system(size: 13, weight: .regular))
                    .tracking(2)
                    .foregroundStyle(palette.text3)
            }
            .padding(.bottom, 60)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

// MARK: - Onboarding pager

private struct OnboardingPager: View {
    @Environment(\.palette) private var palette
    let onFinish: () -> Void
    @State private var index = 0

    private struct Page: Identifiable {
        let id = UUID()
        let symbol: String
        let symbolColor: Color
        let title: String
        let detail: String
    }

    private var pages: [Page] {
        [
            Page(symbol: "list.bullet.rectangle",
                 symbolColor: Color(hex: "#0A84FF"),
                 title: "Your configs,\none library",
                 detail: "Import from QR, clipboard, URL, file or subscription — every node in one organized place."),
            Page(symbol: "chevron.left.forwardslash.chevron.right",
                 symbolColor: palette.success,
                 title: "Any protocol,\none editor",
                 detail: "WireGuard, Reality, Hysteria2, Trojan, Shadowsocks and more — the editor adapts to each."),
            Page(symbol: "bolt.fill",
                 symbolColor: Color(hex: "#BF5AF2"),
                 title: "Connect,\ninstantly",
                 detail: "Tap any configuration to tunnel through it. Kill switch, split routing and DoH built in.")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                ForEach(Array(pages.enumerated()), id: \.offset) { offset, page in
                    VStack(spacing: 0) {
                        Spacer()
                        RoundedRectangle(cornerRadius: 40, style: .continuous)
                            .fill(palette.elev1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 40, style: .continuous)
                                    .strokeBorder(palette.border, lineWidth: 1)
                            )
                            .frame(width: 150, height: 150)
                            .overlay(
                                Image(systemName: page.symbol)
                                    .font(.system(size: 56, weight: .light))
                                    .foregroundStyle(page.symbolColor)
                            )
                            .padding(.bottom, 36)

                        Text(page.title)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(palette.text)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)

                        Text(page.detail)
                            .font(.system(size: 16))
                            .foregroundStyle(palette.text2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 300)
                            .padding(.top, 16)
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: index)

            // Dots
            HStack(spacing: 7) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? palette.accent : palette.text3)
                        .frame(width: i == index ? 20 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.3), value: index)
                }
            }
            .padding(.bottom, 26)

            PrimaryButton(title: "Continue") {
                if index < pages.count - 1 {
                    withAnimation { index += 1 }
                } else {
                    onFinish()
                }
            }
            .padding(.horizontal, 28)
        }
        .padding(.top, 60)
        .padding(.bottom, 48)
    }
}

// MARK: - Permissions

private struct PermissionsStage: View {
    @Environment(\.palette) private var palette
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.accent.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(palette.accent.opacity(0.28), lineWidth: 1)
                )
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(palette.accent)
                )
                .padding(.bottom, 22)

            Text("Enable the VPN tunnel")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(palette.text)

            Text("Nimbus installs a local tunnel to route your selected configurations. Nothing is logged.")
                .font(.system(size: 15))
                .foregroundStyle(palette.text2)
                .lineSpacing(2)
                .padding(.top, 10)

            VStack(spacing: 11) {
                PermissionRow(
                    symbol: "network",
                    tint: palette.accent,
                    title: "VPN Configuration",
                    subtitle: "Required to route traffic",
                    trailing: .granted
                )
                PermissionRow(
                    symbol: "bell.badge",
                    tint: palette.warning,
                    title: "Notifications",
                    subtitle: "Connection & subscription alerts",
                    trailing: .allow
                )
            }
            .padding(.top, 26)

            Spacer()

            PrimaryButton(title: "Continue", action: onContinue)
        }
        .padding(.horizontal, 24)
        .padding(.top, 72)
        .padding(.bottom, 48)
    }
}

private struct PermissionRow: View {
    @Environment(\.palette) private var palette
    enum Trailing { case granted, allow }

    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let trailing: Trailing

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(tint)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text2)
            }
            Spacer()
            switch trailing {
            case .granted:
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.success)
            case .allow:
                Text("Allow")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
        }
        .padding(15)
        .nimbusCard(elevated: false)
    }
}

// MARK: - Login

private struct LoginStage: View {
    @Environment(\.palette) private var palette
    let onSignIn: (String, String) -> Void
    let onSkip: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var revealPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.accent.opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(ShieldGlyph().padding(14))
                .shadow(color: palette.accent.opacity(0.55), radius: 24, x: 0, y: 12)
                .padding(.bottom, 24)

            Text("Sync your library")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(palette.text)

            Text("Sign in to back up and sync configs across devices — or skip and stay fully local.")
                .font(.system(size: 15))
                .foregroundStyle(palette.text2)
                .lineSpacing(2)
                .padding(.top, 6)

            VStack(spacing: 12) {
                FieldBox(label: "Email") {
                    TextField("you@example.com", text: $email)
                        .font(.system(size: 16))
                        .foregroundStyle(palette.text)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                FieldBox(label: "Password") {
                    HStack {
                        Group {
                            if revealPassword {
                                TextField("Passphrase", text: $password)
                            } else {
                                SecureField("Passphrase", text: $password)
                            }
                        }
                        .font(.system(size: 16))
                        .foregroundStyle(palette.text)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        Button {
                            revealPassword.toggle()
                        } label: {
                            Image(systemName: revealPassword ? "eye.slash" : "eye")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(palette.text2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 28)

            PrimaryButton(title: "Sign In") {
                onSignIn(email, password)
            }
            .padding(.top, 20)
            .disabled(email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)

            Button(action: onSkip) {
                Text("Use locally without account")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.text2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 68)
        .padding(.bottom, 48)
    }
}

/// A labeled input box matching the design's login fields.
private struct FieldBox<Content: View>: View {
    @Environment(\.palette) private var palette
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(palette.text3)
            content
        }
        .padding(15)
        .background(palette.elev2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        )
    }
}

#if DEBUG
struct OnboardingFlow_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        return OnboardingFlow()
            .environmentObject(model)
            .nimbusPalette(model.palette)
    }
}
#endif
