import SwiftUI
import NimbusKit
#if canImport(UIKit)
import UIKit
#endif

/// Live Log console — the design's LOGS section. A back button and title sit
/// above a row of filter chips (All / Info / Warnings / Errors) bound to
/// `model.logFilter`; below is a monospaced, auto-scrolling console rendering
/// `model.filteredLogs`, and a bottom action row (Export / Share / Clear).
struct LogsScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    /// When on, the console follows the newest line as entries stream in.
    @State private var autoScroll = true
    /// Text built by Export/Share, presented via a share sheet.
    @State private var shareText: String?
    @State private var showShare = false
    @State private var showClearConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            filterChips
                .padding(.top, 14)
            console
                .padding(.top, 14)
            actionRow
                .padding(.top, 14)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showShare) {
            if let shareText { ShareSheet(items: [shareText]) }
        }
        .confirmationDialog("Clear all logs?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear Log", role: .destructive) {
                haptic(.warning)
                model.clearLogs()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the current session log.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            BackButton(label: "Back") { dismiss() }
            HStack(alignment: .firstTextBaseline) {
                ScreenTitle(title: "Live Log")
                Spacer()
                autoScrollToggle
            }
        }
    }

    /// A compact toggle that pauses/resumes follow-the-tail scrolling.
    private var autoScrollToggle: some View {
        Button {
            autoScroll.toggle()
            haptic(.selection)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: autoScroll ? "arrow.down.to.line" : "pause.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(autoScroll ? "Live" : "Paused")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(autoScroll ? palette.success : palette.text2)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background((autoScroll ? palette.success : palette.text2).opacity(0.14))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(LogFilter.allCases, id: \.self) { filter in
                ChoiceChip(title: filter.rawValue, isSelected: model.logFilter == filter) {
                    model.logFilter = filter
                    haptic(.selection)
                }
            }
        }
    }

    // MARK: - Console

    private var console: some View {
        let logs = model.filteredLogs
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    if logs.isEmpty {
                        Text("No log entries.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(palette.text3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(logs) { entry in
                            LogRow(entry: entry).id(entry.id)
                        }
                    }
                    // Blinking cursor prompt anchored to the tail.
                    CursorPrompt()
                        .id(Self.tailAnchor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
            .background(palette.console)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 1)
            )
            .frame(maxHeight: .infinity)
            .onChange(of: logs.count) { _ in
                guard autoScroll else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(Self.tailAnchor, anchor: .bottom)
                }
            }
            .onChange(of: autoScroll) { on in
                guard on else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(Self.tailAnchor, anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo(Self.tailAnchor, anchor: .bottom)
            }
        }
    }

    private static let tailAnchor = "nimbus.log.tail"

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 10) {
            consoleAction(title: "Export", systemImage: "square.and.arrow.down") {
                Task {
                    let text = await model.exportLogs()
                    await MainActor.run { present(text) }
                }
            }
            consoleAction(title: "Share", systemImage: "square.and.arrow.up") {
                Task {
                    let text = await model.exportLogs()
                    await MainActor.run { present(text) }
                }
            }
            consoleAction(title: "Clear", systemImage: "trash", role: .danger) {
                haptic(.selection)
                showClearConfirm = true
            }
        }
    }

    private enum ActionRole { case neutral, danger }

    private func consoleAction(title: String, systemImage: String, role: ActionRole = .neutral, action: @escaping () -> Void) -> some View {
        let tint = role == .danger ? palette.danger : palette.text
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(role == .danger ? palette.danger.opacity(0.10) : palette.elev2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(role == .danger ? palette.danger.opacity(0.22) : palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func present(_ text: String) {
        shareText = text
        showShare = true
    }

    // MARK: - Haptics

    private enum Haptic { case selection, warning }

    private func haptic(_ kind: Haptic) {
        guard model.settings.haptics else { return }
        #if canImport(UIKit)
        switch kind {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        #endif
    }
}

// MARK: - Log row

/// A single console line: dim timestamp, fixed-width colored level tag, message.
private struct LogRow: View {
    @Environment(\.palette) private var palette
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timeString)
                .foregroundStyle(palette.text3)
                .fixedSize(horizontal: true, vertical: false)
            Text(entry.level.tag)
                .fontWeight(.bold)
                .foregroundStyle(Color(hex: entry.level.tintHex))
                .frame(width: 40, alignment: .leading)
            Text(entry.message)
                .foregroundStyle(palette.text.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11.5, design: .monospaced))
        .textSelection(.enabled)
    }
}

/// The blinking terminal prompt at the tail of the console.
private struct CursorPrompt: View {
    @Environment(\.palette) private var palette
    @State private var on = true

    var body: some View {
        HStack(spacing: 8) {
            Text("➜")
                .foregroundStyle(palette.success)
            Rectangle()
                .fill(palette.success)
                .frame(width: 8, height: 15)
                .opacity(on ? 1 : 0)
        }
        .font(.system(size: 11.5, design: .monospaced))
        .padding(.top, 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                on = false
            }
        }
    }
}

// MARK: - Share sheet

#if canImport(UIKit)
/// A thin `UIActivityViewController` wrapper for sharing/exporting the log text.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#else
private struct ShareSheet: View {
    let items: [Any]
    var body: some View { EmptyView() }
}
#endif

#if DEBUG
struct LogsScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        return NavigationStack {
            LogsScreen()
        }
        .environmentObject(model)
        .nimbusPalette(model.palette)
    }
}
#endif
