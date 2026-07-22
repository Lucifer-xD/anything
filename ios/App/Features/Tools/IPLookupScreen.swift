import SwiftUI
import NimbusKit

/// The design's IP LOOKUP subscreen. An accent-tinted hero card shows the public
/// IP with a "Masked by tunnel" status pill, a placeholder map panel stands in
/// for a geolocation preview, and a grouped info card lists ISP / City / ASN.
struct IPLookupScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    private let publicIP = "149.28.114.20"
    private let coordinate = "40.71°N, 74.00°W"

    private struct Row: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    private let rows: [Row] = [
        Row(label: "ISP", value: "Vultr Holdings"),
        Row(label: "City", value: "New York, NY"),
        Row(label: "ASN", value: "AS20473"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BackButton(label: "Tools") { dismiss() }
                    .padding(.bottom, 4)

                Text("IP Lookup")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(palette.text)
                    .padding(.bottom, 2)

                heroCard
                mapPanel
                infoCard
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

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Public IP · Protected")
                .font(.system(size: 13))
                .foregroundStyle(palette.text2)

            Text(publicIP)
                .font(.system(size: 30, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(palette.text)
                .padding(.top, 4)

            HStack(spacing: 6) {
                Circle()
                    .fill(palette.success)
                    .frame(width: 6, height: 6)
                Text("Masked by tunnel")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.success)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(palette.success.opacity(0.14))
            .clipShape(Capsule())
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(palette.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(palette.accent.opacity(0.28), lineWidth: 1)
        )
    }

    // MARK: - Map placeholder

    private var mapPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.elev1)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)

            VStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(palette.text3)
                Text("[ map: \(coordinate) ]")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.text2)
            }
        }
        .frame(height: 140)
    }

    // MARK: - Info

    private var infoCard: some View {
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
                        .foregroundStyle(palette.text)
                }
                .padding(13)
            }
        }
        .nimbusCard(cornerRadius: 18)
    }
}

#if DEBUG
struct IPLookupScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        IPLookupScreen()
            .environmentObject(model)
            .nimbusPalette(model.palette)
    }
}
#endif
