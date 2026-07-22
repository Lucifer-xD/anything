import SwiftUI
import NimbusKit

/// Usage Statistics — a Phase-3 HIG addition (the imported design has no stats
/// screen). A back button + title sit above a Daily/Weekly/Monthly segmented
/// control, a grid of headline tiles from `model.statsSummary`, an iOS-16-safe
/// SwiftUI bar chart of `UsageAggregator.buckets`, and proportional breakdowns
/// for protocol and server usage. Shows a friendly empty state with no sessions.
struct StatisticsScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var period: UsagePeriod = .weekly

    private var summary: UsageSummary { model.statsSummary }
    private var buckets: [UsageBucket] { UsageAggregator.buckets(model.sessions, period: period) }
    private var protocolSlices: [UsageSlice] { UsageAggregator.byProtocol(model.sessions) }
    private var serverSlices: [UsageSlice] { UsageAggregator.byServer(model.sessions) }
    private var hasData: Bool { !model.sessions.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if hasData {
                    periodPicker
                    summaryGrid
                    chartCard
                    protocolCard
                    serverCard
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            BackButton(label: "Settings") { dismiss() }
            ScreenTitle(title: "Statistics")
        }
    }

    // MARK: - Period control

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(UsagePeriod.allCases, id: \.self) { p in
                Text(p.rawValue).tag(p)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary tiles

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tile(title: "Total Data", value: ByteFormat.short(summary.totalBytes),
                 systemImage: "arrow.up.arrow.down", tint: palette.accent)
            tile(title: "Sessions", value: "\(summary.sessionCount)",
                 systemImage: "bolt.fill", tint: palette.success)
            tile(title: "Download", value: ByteFormat.short(summary.totalRxBytes),
                 systemImage: "arrow.down", tint: palette.success)
            tile(title: "Upload", value: ByteFormat.short(summary.totalTxBytes),
                 systemImage: "arrow.up", tint: palette.warning)
            tile(title: "Total Time", value: ByteFormat.duration(summary.totalConnectedSeconds),
                 systemImage: "clock.fill", tint: palette.accent)
            tile(title: "Avg Session", value: ByteFormat.duration(summary.averageSessionSeconds),
                 systemImage: "timer", tint: palette.text2)
        }
    }

    private func tile(title: String, value: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .nimbusCard()
    }

    // MARK: - Bar chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(title: "DATA USAGE")
                Spacer()
                Text(ByteFormat.short(summary.totalBytes))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.text2)
            }
            UsageBarChart(buckets: buckets, period: period)
                .frame(height: 150)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nimbusCard()
    }

    // MARK: - Protocol usage

    private var protocolCard: some View {
        breakdownCard(title: "PROTOCOL USAGE", slices: protocolSlices, tint: palette.accent)
    }

    // MARK: - Server usage

    private var serverCard: some View {
        breakdownCard(title: "TOP SERVERS", slices: Array(serverSlices.prefix(5)), tint: palette.success)
    }

    private func breakdownCard(title: String, slices: [UsageSlice], tint: Color) -> some View {
        let maxBytes = slices.map(\.totalBytes).max() ?? 1
        return VStack(alignment: .leading, spacing: 14) {
            SectionLabel(title: title)
            if slices.isEmpty {
                Text("No usage yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text3)
            } else {
                VStack(spacing: 12) {
                    ForEach(slices) { slice in
                        breakdownRow(slice: slice, maxBytes: maxBytes, tint: tint)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nimbusCard()
    }

    private func breakdownRow(slice: UsageSlice, maxBytes: UInt64, tint: Color) -> some View {
        let fraction = maxBytes == 0 ? 0 : Double(slice.totalBytes) / Double(maxBytes)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(slice.key)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Text(ByteFormat.short(slice.totalBytes))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.text2)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.elev2)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(palette.text3)
            Text("No usage yet")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(palette.text)
            Text("Connect to a server to start recording session statistics. Your data usage, connection time and server history will appear here.")
                .font(.system(size: 14))
                .foregroundStyle(palette.text2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 20)
        .nimbusCard()
        .padding(.top, 12)
    }
}

// MARK: - Bar chart (iOS 16-safe, no Swift Charts)

/// A plain-SwiftUI bar chart of per-period usage. Bar heights are normalized to
/// the largest bucket; every bar carries a compact axis label below it.
private struct UsageBarChart: View {
    @Environment(\.palette) private var palette
    let buckets: [UsageBucket]
    let period: UsagePeriod

    private var maxBytes: UInt64 { buckets.map(\.totalBytes).max() ?? 1 }

    var body: some View {
        if buckets.isEmpty {
            Text("No data for this period.")
                .font(.system(size: 13))
                .foregroundStyle(palette.text3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geo in
                let labelHeight: CGFloat = 18
                let barsHeight = max(0, geo.size.height - labelHeight)
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(buckets) { bucket in
                        bar(for: bucket, maxHeight: barsHeight, labelHeight: labelHeight)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var barSpacing: CGFloat { buckets.count > 14 ? 3 : 7 }

    private func bar(for bucket: UsageBucket, maxHeight: CGFloat, labelHeight: CGFloat) -> some View {
        let fraction = maxBytes == 0 ? 0 : Double(bucket.totalBytes) / Double(maxBytes)
        let height = max(4, maxHeight * fraction)
        return VStack(spacing: 6) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.accent.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: height)
            Text(label(for: bucket.periodStart))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(palette.text3)
                .lineLimit(1)
                .frame(height: labelHeight)
                .fixedSize()
        }
        .frame(maxWidth: .infinity)
    }

    private func label(for date: Date) -> String {
        let f = DateFormatter()
        switch period {
        case .daily: f.dateFormat = "d/M"
        case .weekly: f.dateFormat = "d MMM"
        case .monthly: f.dateFormat = "MMM"
        }
        return f.string(from: date)
    }
}

#if DEBUG
struct StatisticsScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        return NavigationStack {
            StatisticsScreen()
        }
        .environmentObject(model)
        .nimbusPalette(model.palette)
    }
}
#endif
