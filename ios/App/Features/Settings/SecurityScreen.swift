import SwiftUI
import NimbusKit

/// The Security subscreen pushed from Settings — implements the design's SECURITY
/// section. CONFIG PROTECTION exposes the Face ID and App Lock toggles bound to
/// `model.settings`; INTEGRITY shows read-only device posture rows with colored
/// status text.
struct SecurityScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BackButton(label: "Settings") { dismiss() }
                Text("Security")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(palette.text)

                configProtection
                integrity
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden)
    }

    // MARK: - Config protection

    private var configProtection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "CONFIG PROTECTION")
            VStack(spacing: 0) {
                toggleRow(icon: "faceid", tint: palette.accent,
                          label: "Face ID to unlock configs", isOn: $model.settings.faceID)
                divider
                toggleRow(icon: "lock.fill", tint: Color(hex: "#5E5CE6"),
                          label: "App Lock on launch", isOn: $model.settings.appLock)
            }
            .nimbusCard(cornerRadius: 16, elevated: false)
        }
    }

    // MARK: - Integrity

    private var integrity: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "INTEGRITY")
            VStack(spacing: 0) {
                statusRow(label: "Encrypted storage", status: "Active", color: palette.success)
                divider
                statusRow(label: "Jailbreak detection", status: "Clean", color: palette.success)
                divider
                statusRow(label: "HWID binding", status: "This device", color: palette.accent)
            }
            .nimbusCard(cornerRadius: 16, elevated: false)
        }
    }

    // MARK: - Rows

    private var divider: some View {
        Rectangle()
            .fill(palette.divider)
            .frame(height: 1)
            .padding(.leading, 56)
    }

    private func toggleRow(icon: String, tint: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                )
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(palette.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func statusRow(label: String, status: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(status)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

#if DEBUG
struct SecurityScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        NavigationStack { SecurityScreen() }
            .environmentObject(model)
            .nimbusPalette(model.palette)
    }
}
#endif
