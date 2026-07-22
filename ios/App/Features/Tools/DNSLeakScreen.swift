import SwiftUI
import NimbusKit

/// The design's DNS LEAK subscreen. A green shield hero declares "No Leaks
/// Detected", followed by a grouped card of key/value rows (Visible IP,
/// Resolver, Encryption) confirming queries route through the tunnel.
struct DNSLeakScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    /// A single row in the details card.
    private struct Row: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        var tint: Color? = nil
    }

    private var rows: [Row] {
        [
            Row(label: "Visible IP", value: "149.28.114.20"),
            Row(label: "Resolver", value: "10.66.0.1"),
            Row(label: "Encryption", value: "DNS over HTTPS", tint: palette.success),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BackButton(label: "Tools") { dismiss() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 18)

                hero
                    .padding(.bottom, 22)

                detailsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(palette.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.success.opacity(0.12))
                .frame(width: 78, height: 78)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(palette.success.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(palette.success)
                )

            Text("No Leaks Detected")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(palette.success)
                .padding(.top, 14)

            Text("All DNS queries route through the tunnel.")
                .font(.system(size: 14))
                .foregroundStyle(palette.text2)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Details

    private var detailsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(height: 1)
                }
                HStack {
                    Text(row.label)
                        .font(.system(size: 15))
                        .foregroundStyle(palette.text2)
                    Spacer()
                    Text(row.value)
                        .font(.system(size: 15))
                        .foregroundStyle(row.tint ?? palette.text)
                }
                .padding(14)
            }
        }
        .nimbusCard(cornerRadius: 18)
    }
}

#if DEBUG
struct DNSLeakScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        DNSLeakScreen()
            .environmentObject(model)
            .nimbusPalette(model.palette)
    }
}
#endif
