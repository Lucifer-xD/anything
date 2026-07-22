import SwiftUI
import NimbusKit

/// Server Management — browse, search, categorize, sort, favorite and latency-test
/// the reusable server endpoints backing the configurations. A Phase-3 addition
/// designed to HIG (no imported design section); reads from `AppModel.services.servers`
/// (a `ServerRegistry` actor) and mirrors results into local `@State` for the list.
struct ServersScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var selectedCategory: String? = nil   // nil == "All"
    @State private var sort: ServerSort = .latency
    @State private var servers: [Server] = []
    @State private var isTesting = false

    /// Distinct categories from the seeded servers, plus the leading "All" chip.
    private var categories: [String] {
        Array(Set(model.servers.map(\.category))).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                SearchField(text: $search, placeholder: "Search servers, cities, tags")
                categoryChips
                controlsRow

                if servers.isEmpty {
                    emptyState.padding(.top, 24)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(servers) { server in
                            ServerRow(server: server) {
                                toggleFavorite(server)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(palette.bg.ignoresSafeArea())
        .toolbar(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .task { await reload() }
        .onChange(of: search) { _ in Task { await reload() } }
        .onChange(of: selectedCategory) { _ in Task { await reload() } }
        .onChange(of: sort) { _ in Task { await reload() } }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            BackButton(label: "Back") { dismiss() }
            HStack(alignment: .firstTextBaseline) {
                ScreenTitle(title: "Servers")
                Spacer()
                Text("\(servers.count)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text3)
            }
        }
    }

    // MARK: - Category chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChoiceChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(categories, id: \.self) { category in
                    ChoiceChip(title: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - Sort + latency controls

    private var controlsRow: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(ServerSort.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                    Text(sort.rawValue).font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .foregroundStyle(palette.text)
                .background(palette.elev2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(palette.border, lineWidth: 1))
            }

            Spacer(minLength: 0)

            Button(action: testAll) {
                HStack(spacing: 7) {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(isTesting ? "Testing…" : "Test all latency")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 15).padding(.vertical, 9)
                .foregroundStyle(.white)
                .background(palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: palette.accent.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isTesting)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe.desk")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(palette.text3)
            Text("No servers found")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.text)
            Text("Try a different search or category.")
                .font(.system(size: 14))
                .foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .nimbusCard()
    }

    // MARK: - Data

    private func reload() async {
        servers = await model.services.servers.list(
            category: selectedCategory,
            search: search,
            sort: sort
        )
    }

    private func testAll() {
        guard !isTesting else { return }
        isTesting = true
        Task {
            await model.services.servers.refreshLatencies()
            await reload()
            await MainActor.run { isTesting = false }
        }
    }

    private func toggleFavorite(_ server: Server) {
        Task {
            await model.services.servers.setFavorite(server.id, !server.isFavorite)
            await reload()
        }
    }
}

// MARK: - Row

/// A single server list row: flag + name, "city · category" subtitle, tags,
/// a latency pill, a health dot, and a favorite toggle.
private struct ServerRow: View {
    @Environment(\.palette) private var palette
    let server: Server
    let onToggleFavorite: () -> Void

    private var subtitle: String {
        if let city = server.city, !city.isEmpty {
            return "\(city) · \(server.category)"
        }
        return server.category
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(server.flagEmoji.isEmpty ? "🏳️" : server.flagEmoji)
                .font(.system(size: 26))
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(server.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    Circle()
                        .fill(Color(hex: server.health.tintHex))
                        .frame(width: 7, height: 7)
                }
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)

                if !server.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(server.tags.prefix(3), id: \.self) { tag in
                            TagChip(text: tag)
                        }
                    }
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                LatencyPill(milliseconds: server.latencyMillis)
                Button(action: onToggleFavorite) {
                    Image(systemName: server.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(server.isFavorite ? palette.warning : palette.text3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(13)
        .nimbusCard()
    }
}

#if DEBUG
struct ServersScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        return ServersScreen()
            .environmentObject(model)
            .nimbusPalette(model.palette)
    }
}
#endif
