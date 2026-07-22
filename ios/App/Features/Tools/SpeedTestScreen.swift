import SwiftUI
import NimbusKit

/// The design's SPEED TEST subscreen. A 270° circular gauge (two trimmed
/// `Circle`s in a `ZStack`) shows the download figure, a three-up Upload / Ping /
/// Jitter stat row summarises the run, and "Run Again" animates fresh, plausible
/// numbers through `@State` + `withAnimation` driven by a stepping `Task`.
struct SpeedTestScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    // Animated readouts.
    @State private var download: Double = 187.4
    @State private var upload: Double = 64.2
    @State private var ping: Int = 14
    @State private var jitter: Double = 2.1
    @State private var isRunning = false

    /// Full-scale value the gauge maps to a complete 270° sweep.
    private let fullScale: Double = 500

    private var fraction: Double { min(max(download / fullScale, 0), 1) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BackButton(label: "Tools") { dismiss() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 18)

                Text("Speed Test")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity)

                gauge
                    .padding(.vertical, 26)

                statRow

                PrimaryButton(title: isRunning ? "Testing…" : "Run Again",
                              systemImage: isRunning ? nil : "arrow.clockwise") {
                    Task { await runTest() }
                }
                .disabled(isRunning)
                .opacity(isRunning ? 0.7 : 1)
                .padding(.top, 22)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(palette.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden)
    }

    // MARK: - Gauge

    private var gauge: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(palette.elev2, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: 0.75 * fraction)
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(135))
                .shadow(color: palette.accent.opacity(0.45), radius: 10)

            VStack(spacing: 2) {
                Text(String(format: "%.1f", download))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.text)
                Text("Mbps download")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.text2)
            }
        }
        .frame(width: 220, height: 220)
    }

    // MARK: - Stat row

    private var statRow: some View {
        HStack(spacing: 10) {
            stat(title: "Upload", value: String(format: "%.1f", upload), tint: palette.accent)
            stat(title: "Ping", value: "\(ping)", tint: palette.success)
            stat(title: "Jitter", value: String(format: "%.1f", jitter), tint: palette.warning)
        }
    }

    private func stat(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(palette.text2)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .nimbusCard(cornerRadius: 16)
    }

    // MARK: - Fake test run

    private func runTest() async {
        guard !isRunning else { return }
        isRunning = true
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        let targetDown = Double.random(in: 120...480)
        let targetUp = Double.random(in: 28...110)
        let targetPing = Int.random(in: 8...42)
        let targetJitter = Double.random(in: 0.6...4.6)

        let steps = 26
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let eased = 1 - pow(1 - t, 3)
            let jitterNoise = Double.random(in: 0.92...1.06)
            withAnimation(.easeOut(duration: 0.07)) {
                download = targetDown * eased * jitterNoise
                upload = targetUp * eased
                ping = Int((Double(targetPing) * (1.6 - 0.6 * eased)).rounded())
                jitter = targetJitter * (1.3 - 0.3 * eased)
            }
            try? await Task.sleep(nanoseconds: 70_000_000)
        }

        withAnimation(.easeOut(duration: 0.25)) {
            download = targetDown
            upload = targetUp
            ping = targetPing
            jitter = targetJitter
        }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        isRunning = false
    }
}

#if DEBUG
struct SpeedTestScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        SpeedTestScreen()
            .environmentObject(model)
            .nimbusPalette(model.palette)
    }
}
#endif
