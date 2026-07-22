import SwiftUI
import NimbusKit

/// The Tools tab — the design's TOOLS section. A titled grid of diagnostic
/// utility cards that push their respective subscreens (Speed Test, DNS Leak,
/// IP Lookup) or route into sibling features (Live Log, Servers, Create) via a
/// single `navigationDestination` keyed off ``ToolsScreen/Destination``.
struct ToolsScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette

    /// Push targets for the tool grid.
    enum Destination: Hashable {
        case speedTest, dnsLeak, ipLookup, logs, servers, create
    }

    /// A single tool card descriptor.
    private struct Tool: Identifiable {
        let id = UUID()
        let name: String
        let subtitle: String
        let symbol: String
        let tint: Color
        let destination: Destination
    }

    private var tools: [Tool] {
        [
            Tool(name: "Speed Test", subtitle: "Measure throughput",
                 symbol: "speedometer", tint: Color(hex: "#0A84FF"), destination: .speedTest),
            Tool(name: "DNS Leak Test", subtitle: "Check DNS exposure",
                 symbol: "shield.lefthalf.filled", tint: palette.success, destination: .dnsLeak),
            Tool(name: "IP Lookup", subtitle: "Inspect your IP",
                 symbol: "globe", tint: Color(hex: "#5E5CE6"), destination: .ipLookup),
            Tool(name: "Ping Test", subtitle: "Latency probe",
                 symbol: "wave.3.forward", tint: Color(hex: "#64D2FF"), destination: .speedTest),
            Tool(name: "Traceroute", subtitle: "Trace network hops",
                 symbol: "point.topleft.down.to.point.bottomright.curvepath", tint: Color(hex: "#BF5AF2"), destination: .logs),
            Tool(name: "Live Log", subtitle: "Stream tunnel events",
                 symbol: "text.alignleft", tint: palette.warning, destination: .logs),
            Tool(name: "Servers", subtitle: "Browse locations",
                 symbol: "server.rack", tint: palette.accent, destination: .servers),
            Tool(name: "QR Scanner", subtitle: "Scan a config",
                 symbol: "qrcode.viewfinder", tint: palette.success, destination: .create),
        ]
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(tools) { tool in
                            NavigationLink(value: tool.destination) {
                                card(for: tool)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 108)
            }
            .background(palette.bg.ignoresSafeArea())
            .toolbar(.hidden)
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .speedTest: SpeedTestScreen()
                case .dnsLeak: DNSLeakScreen()
                case .ipLookup: IPLookupScreen()
                case .logs: LogsScreen()
                case .servers: ServersScreen()
                case .create: CreateWizardView(app: model)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tools")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(palette.text)
            Text("Diagnostics & network utilities.")
                .font(.system(size: 14))
                .foregroundStyle(palette.text2)
        }
    }

    // MARK: - Card

    private func card(for tool: Tool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(tool.tint.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: tool.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tool.tint)
                )
            Text(tool.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.text)
                .padding(.top, 12)
            Text(tool.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(palette.text2)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .nimbusCard(cornerRadius: 18)
    }
}

#if DEBUG
struct ToolsScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        ToolsScreen()
            .environmentObject(model)
            .nimbusPalette(model.palette)
    }
}
#endif
