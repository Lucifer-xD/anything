import SwiftUI
import NimbusKit

/// The full-screen App-Lock overlay shown while `model.isLocked` is true.
/// Presents the Nimbus shield over a blurred backdrop and runs biometric
/// unlock (`services.appLock.unlock()`) on appear and on the button tap,
/// clearing `model.isLocked` on success. Design: an app-designed lock screen
/// consistent with the SPLASH / LOGIN sections.
struct LockScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette

    @State private var isAuthenticating = false
    @State private var failed = false

    private var biometryName: String {
        model.services.appLock.biometryType.displayName
    }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()

            // Soft accent wash behind the frosted layer.
            RadialGradient(
                colors: [palette.accent.opacity(0.18), palette.bg],
                center: UnitPoint(x: 0.5, y: 0.32),
                startRadius: 20,
                endRadius: 460
            )
            .ignoresSafeArea()

            // Frosted blur pane covering the underlying library.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.accent, palette.accent.opacity(0.55)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .overlay(
                        ZStack {
                            LockedShield()
                                .stroke(.white, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                                .padding(20)
                        }
                    )
                    .shadow(color: palette.accent.opacity(0.55), radius: 28, x: 0, y: 16)

                Text("Nimbus locked")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(palette.text)

                Text(failed
                     ? "Authentication failed. Try again."
                     : "Your library is protected. Unlock to continue.")
                    .font(.system(size: 15))
                    .foregroundStyle(failed ? palette.danger : palette.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                Button(action: attemptUnlock) {
                    HStack(spacing: 8) {
                        if isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "faceid")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        Text(isAuthenticating ? "Authenticating…" : "Unlock with \(biometryName)")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: palette.accent.opacity(0.45), radius: 18, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .onAppear(perform: attemptUnlock)
    }

    private func attemptUnlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        failed = false
        Task {
            let ok = await model.services.appLock.unlock(reason: "Unlock your Nimbus library")
            await MainActor.run {
                isAuthenticating = false
                if ok {
                    withAnimation(.easeInOut(duration: 0.3)) { model.isLocked = false }
                } else {
                    failed = true
                }
            }
        }
    }
}

/// A shield with a small keyhole/lock accent — the locked variant of the mark.
private struct LockedShield: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x / 24 * w, y: rect.minY + y / 24 * h)
        }
        var path = Path()
        // Shield outline
        path.move(to: p(12, 2))
        path.addLine(to: p(20, 6))
        path.addLine(to: p(20, 11))
        path.addCurve(to: p(12, 22), control1: p(20, 16), control2: p(16.6, 20.3))
        path.addCurve(to: p(4, 11), control1: p(7.4, 20.3), control2: p(4, 16))
        path.addLine(to: p(4, 6))
        path.closeSubpath()
        // Padlock body
        path.addRoundedRect(in: CGRect(x: rect.minX + 8.5 / 24 * w,
                                       y: rect.minY + 11.5 / 24 * h,
                                       width: 7 / 24 * w,
                                       height: 5.5 / 24 * h),
                            cornerSize: CGSize(width: 1.2 / 24 * w, height: 1.2 / 24 * h))
        // Padlock shackle
        path.move(to: p(9.8, 11.5))
        path.addLine(to: p(9.8, 10))
        path.addCurve(to: p(14.2, 10), control1: p(9.8, 8), control2: p(14.2, 8))
        path.addLine(to: p(14.2, 11.5))
        return path
    }
}

#if DEBUG
struct LockScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        return LockScreen()
            .environmentObject(model)
            .nimbusPalette(model.palette)
    }
}
#endif
