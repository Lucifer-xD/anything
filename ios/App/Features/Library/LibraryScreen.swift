import SwiftUI
import NimbusKit

/// The app's main screen — the Configs tab. Implements the HOME · CONFIG LIBRARY
/// design section: header with theme/import actions, the dashboard connection
/// card, search, filter chips, the scrollable list of configuration cards, and a
/// dashed "New Configuration" affordance that opens the create wizard.
struct LibraryScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette

    @State private var path: [UUID] = []
    @State private var showImport = false
    @State private var showCreate = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, 16)

                    DashboardConnectionCard()

                    SearchField(text: $model.searchText)
                        .padding(.top, 16)

                    filterChips
                        .padding(.top, 14)

                    configList
                        .padding(.top, 18)

                    newConfigButton
                        .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 108)
            }
            .background(palette.bg.ignoresSafeArea())
            .toolbar(.hidden)
            .navigationDestination(for: UUID.self) { id in
                ConfigDetailScreen(configID: id)
            }
        }
        .sheet(isPresented: $showImport) {
            ImportMethodsSheet()
                .nimbusPalette(model.palette)
        }
        .sheet(isPresented: $showCreate) {
            CreateWizardView(app: model)
                .nimbusPalette(model.palette)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            ScreenTitle(title: "Configurations", eyebrow: "LIBRARY")
            Spacer(minLength: 8)
            HStack(spacing: 9) {
                roundButton(systemImage: "circle.lefthalf.filled") { model.cycleTheme() }
                roundButton(systemImage: "square.and.arrow.down") { showImport = true }
            }
        }
    }

    private func roundButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.text)
                .frame(width: 38, height: 38)
                .background(palette.elev2)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.filterChips) { chip in
                    ChoiceChip(title: chip.title, isSelected: chip.filter == model.filter) {
                        model.filter = chip.filter
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - Config list

    @ViewBuilder
    private var configList: some View {
        let configs = model.visibleConfigs
        if configs.isEmpty {
            emptyState
        } else {
            VStack(spacing: 11) {
                ForEach(configs) { config in
                    ConfigCardView(config: config) { path.append(config.id) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(palette.text3)
            Text(model.searchText.isEmpty ? "No configurations yet" : "No matches")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.text2)
            Text(model.searchText.isEmpty ? "Import or create one to get started."
                                          : "Try a different search or filter.")
                .font(.system(size: 13))
                .foregroundStyle(palette.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    // MARK: - New configuration

    private var newConfigButton: some View {
        Button { showCreate = true } label: {
            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("New Configuration")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(palette.accent)
            .frame(maxWidth: .infinity)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(palette.accent.opacity(0.4),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }
}

/// A compact sheet listing the ways to bring configurations into the library.
/// Each method funnels raw text into `model.importText`.
private struct ImportMethodsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var pastedText = ""
    @State private var status: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(title: "IMPORT FROM")

                    VStack(spacing: 10) {
                        method(icon: "doc.on.clipboard", title: "Paste from Clipboard",
                               subtitle: "Detect links or a subscription blob") {
                            importClipboard()
                        }
                        method(icon: "qrcode.viewfinder", title: "Scan QR Code",
                               subtitle: "Use the create wizard to scan") {
                            model.tab = .library
                            dismiss()
                        }
                    }

                    SectionLabel(title: "PASTE MANUALLY")
                    VStack(alignment: .leading, spacing: 10) {
                        TextEditor(text: $pastedText)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(palette.text)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 110)
                            .padding(10)
                            .background(palette.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(palette.border, lineWidth: 1))

                        PrimaryButton(title: "Import Text", systemImage: "arrow.down.doc") {
                            importPasted()
                        }
                    }

                    if let status {
                        Text(status)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.text2)
                    }
                }
                .padding(20)
            }
            .background(palette.bg.ignoresSafeArea())
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func method(icon: String, title: String, subtitle: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 42, height: 42)
                    .background(palette.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Text(subtitle).font(.system(size: 12))
                        .foregroundStyle(palette.text2)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.text3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nimbusCard()
        }
        .buttonStyle(.plain)
    }

    private func importClipboard() {
        #if canImport(UIKit)
        let text = UIPasteboard.general.string ?? ""
        #else
        let text = ""
        #endif
        guard !text.isEmpty else { status = "Clipboard is empty."; return }
        runImport(text, source: .clipboard)
    }

    private func importPasted() {
        let text = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { status = "Nothing to import." ; return }
        runImport(text, source: .manual)
    }

    private func runImport(_ text: String, source: ConfigSource) {
        Task {
            let result = await model.importText(text, source: source)
            let count = result.configs.count
            if count > 0 {
                status = "Imported \(count) configuration\(count == 1 ? "" : "s")."
                try? await Task.sleep(nanoseconds: 500_000_000)
                dismiss()
            } else {
                status = "No configurations found in that text."
            }
        }
    }
}
