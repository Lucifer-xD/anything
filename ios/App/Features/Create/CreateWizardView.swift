import SwiftUI
import NimbusKit

/// The multi-step "Add a configuration" wizard presented as a sheet from the
/// library. Implements the design's CREATE WIZARD section: a top Cancel/step/Back
/// bar, a segmented progress indicator, and a body that adapts to the two paths
/// (import: Source → Input → Preview; manual/template: Source → Protocol → Configure → Review).
struct CreateWizardView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    let app: AppModel
    @StateObject private var wizard: CreateWizardModel

    init(app: AppModel) {
        self.app = app
        _wizard = StateObject(wrappedValue: CreateWizardModel(app: app))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            progressBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    body(for: wizard)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            footer
        }
        .background(palette.bg.ignoresSafeArea())
        .toolbar(.hidden)
        .tint(palette.accent)
    }

    // MARK: - Header

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.system(size: 16))
                .foregroundStyle(palette.accent)
            Spacer()
            Text(wizard.stepLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.text2)
            Spacer()
            Button("Back") { withAnimation(.easeInOut(duration: 0.2)) { wizard.back() } }
                .font(.system(size: 16))
                .foregroundStyle(palette.accent)
                .opacity(wizard.step == 0 ? 0 : 1)
                .disabled(wizard.step == 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(0..<wizard.stepCount, id: \.self) { index in
                Capsule()
                    .fill(index <= wizard.step ? palette.accent : palette.elev2)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .animation(.easeInOut(duration: 0.3), value: wizard.step)
    }

    // MARK: - Footer CTA

    private var footer: some View {
        PrimaryButton(title: wizard.nextTitle) {
            Task {
                let wasLast = wizard.step >= wizard.lastStep
                let savedID = await wizard.next()
                if savedID != nil {
                    model.tab = .library
                    dismiss()
                } else if wasLast {
                    // Import path completed on its final step.
                    dismiss()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .disabled(wizard.isBusy)
    }

    // MARK: - Body switch

    @ViewBuilder
    private func body(for wizard: CreateWizardModel) -> some View {
        if wizard.isMethodStep {
            methodStep
        } else if wizard.isProtocolStep {
            protocolStep
        } else if wizard.isConfigureStep {
            configureStep
        } else if wizard.isReviewStep {
            reviewStep
        } else if wizard.isInputStep {
            inputStep
        } else if wizard.isPreviewStep {
            previewStep
        }
    }

    // MARK: - Step 0: method

    private struct MethodCard: Identifiable {
        let method: CreateWizardModel.Method
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
        var id: String { method.id }
    }

    private var methodCards: [MethodCard] {
        [
            .init(method: .qr, title: "Scan QR", subtitle: "Point the camera at a config code", icon: "qrcode.viewfinder", tint: palette.accent),
            .init(method: .clipboard, title: "Paste from Clipboard", subtitle: "vless:// · ss:// · subscription link", icon: "doc.on.clipboard", tint: palette.success),
            .init(method: .url, title: "Import from URL", subtitle: "Fetch a subscription or config link", icon: "link", tint: Color(hex: "#64D2FF")),
            .init(method: .file, title: "Import File", subtitle: ".json · .yaml · .conf · .zip", icon: "arrow.down.doc", tint: palette.warning),
            .init(method: .manual, title: "Create Manually", subtitle: "Build a tunnel field by field", icon: "square.and.pencil", tint: Color(hex: "#BF5AF2")),
            .init(method: .template, title: "From Template", subtitle: "Start from a recommended preset", icon: "square.grid.2x2", tint: Color(hex: "#5E5CE6")),
        ]
    }

    private var methodStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "Add a configuration",
                       subtitle: "Import an existing config or build one from scratch.")
            VStack(spacing: 11) {
                ForEach(methodCards) { card in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { wizard.select(card.method) }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: card.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(card.tint)
                                .frame(width: 42, height: 42)
                                .background(card.tint.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(palette.text)
                                Text(card.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(palette.text2)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(palette.text3)
                        }
                        .padding(15)
                        .nimbusCard(cornerRadius: 16, elevated: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 1 (manual): protocol

    private var protocolStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "Choose a protocol",
                       subtitle: "The editor adapts to the protocol you pick.")
            VStack(spacing: 10) {
                ForEach(wizard.protocols, id: \.self) { kind in
                    let isSelected = wizard.selectedProtocol == kind
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { wizard.selectProtocol(kind) }
                    } label: {
                        HStack(spacing: 13) {
                            ProtocolChip(kind: kind)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 7) {
                                    Text(kind.metadata.displayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(palette.text)
                                    if kind.metadata.isRecommended {
                                        Text("FAST")
                                            .font(.system(size: 9, weight: .bold))
                                            .tracking(0.4)
                                            .foregroundStyle(palette.success)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(palette.success.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    }
                                }
                                Text(kind.metadata.tagline)
                                    .font(.system(size: 12))
                                    .foregroundStyle(palette.text2)
                            }
                            Spacer(minLength: 8)
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(palette.accent)
                            }
                        }
                        .padding(14)
                        .background(isSelected ? palette.accent.opacity(0.08) : palette.elev1)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(isSelected ? palette.accent.opacity(0.5) : palette.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 2 (manual): configure

    private var configureStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ProtocolChip(kind: wizard.selectedProtocol)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wizard.selectedProtocol.metadata.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(palette.text)
                    Text("Configure the tunnel")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.text2)
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 16)

            ProtocolFormView(sections: wizard.schema, fields: $wizard.fields)
        }
    }

    // MARK: - Step 3 (manual): review

    private var reviewRows: [(String, String)] {
        let config = wizard.buildConfig()
        var rows: [(String, String)] = [
            ("Name", wizard.reviewName),
            ("Protocol", wizard.selectedProtocol.metadata.displayName),
        ]
        if !config.host.isEmpty { rows.append(("Server", config.host)) }
        rows.append(("Port", String(config.port)))
        rows.append(("Transport", config.transportLabel))
        return rows
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "Review & save",
                       subtitle: "Confirm the configuration before adding it.")

            // Summary card
            HStack(spacing: 11) {
                Text(wizard.selectedProtocol.metadata.abbreviation)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(wizard.selectedProtocol.tint)
                    .frame(width: 42, height: 42)
                    .background(palette.elev1)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(wizard.reviewName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(palette.text)
                    Text(wizard.selectedProtocol.metadata.displayName)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.text2)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(wizard.selectedProtocol.tint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(palette.border, lineWidth: 1))

            // Key/value rows
            VStack(spacing: 0) {
                ForEach(Array(reviewRows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().overlay(palette.divider) }
                    HStack(spacing: 12) {
                        Text(row.0)
                            .font(.system(size: 14))
                            .foregroundStyle(palette.text2)
                        Spacer(minLength: 8)
                        Text(row.1)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(palette.text)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
            }
            .nimbusCard(cornerRadius: 16, elevated: false)
            .padding(.top, 14)

            SectionLabel(title: "TAGS")
                .padding(.top, 18)
                .padding(.bottom, 9)

            FlowTags(tags: wizard.allTags, selected: wizard.tags) { tag in
                withAnimation(.easeInOut(duration: 0.15)) { wizard.toggleTag(tag) }
            }
        }
    }

    // MARK: - Step 1 (import): input

    @ViewBuilder
    private var inputStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: inputTitle, subtitle: inputSubtitle)
            switch wizard.method {
            case .qr:
                qrPlaceholder
            case .clipboard:
                clipboardInput
            case .url:
                urlInput
            case .file:
                fileDropPlaceholder
            default:
                clipboardInput
            }
        }
    }

    private var inputTitle: String {
        switch wizard.method {
        case .qr: return "Scan a QR code"
        case .clipboard: return "Paste your config"
        case .url: return "Import from URL"
        case .file: return "Import a file"
        default: return "Import"
        }
    }

    private var inputSubtitle: String {
        switch wizard.method {
        case .qr: return "Line up the code inside the frame."
        case .clipboard: return "Drop in a share link or subscription blob."
        case .url: return "We'll fetch and parse the link for you."
        case .file: return "Pick an exported config or bundle."
        default: return ""
        }
    }

    private var qrPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.console)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(palette.border, lineWidth: 1))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.accent.opacity(0.6), lineWidth: 2)
                .padding(40)
            Rectangle()
                .fill(palette.accent)
                .frame(height: 2)
                .shadow(color: palette.accent, radius: 8)
                .padding(.horizontal, 40)
            VStack(spacing: 10) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(palette.text3)
                Text("Point camera at QR")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.text3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var clipboardInput: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                if wizard.inputText.isEmpty {
                    Text("vless://… or ss://… or paste a subscription link")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(palette.text3)
                        .padding(.horizontal, 18).padding(.vertical, 22)
                }
                TextEditor(text: $wizard.inputText)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(palette.text)
                    .scrollContentBackground(.hidden)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 150)
                    .padding(10)
            }
            .background(palette.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(palette.border, lineWidth: 1))

            Button {
                wizard.pasteFromClipboard()
            } label: {
                Text("Paste from Clipboard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(palette.elev2)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var urlInput: some View {
        VStack(spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "link")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text2)
                TextField("https://sub.example.com/link", text: $wizard.inputText)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(palette.text)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(palette.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border, lineWidth: 1))

            Toggle(isOn: $wizard.treatAsSubscription) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Treat as subscription")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.text)
                    Text("Keep nodes grouped and auto-updating")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.text2)
                }
            }
            .tint(palette.accent)
            .padding(14)
            .nimbusCard(cornerRadius: 16, elevated: false)
        }
    }

    private var fileDropPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(palette.accent)
            Text("Choose a file")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.text)
            Text(".json · .yaml · .conf · .zip")
                .font(.system(size: 12))
                .foregroundStyle(palette.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40).padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(palette.border)
        )
    }

    // MARK: - Step 2 (import): preview

    private var previewStep: some View {
        let configs = wizard.previewResult?.configs ?? []
        return VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: configs.isEmpty ? "Nothing found" : "Found \(configs.count) config\(configs.count == 1 ? "" : "s")",
                       subtitle: configs.isEmpty ? "We couldn't parse any configs from that input." : "These will be imported into your library.")
            if configs.isEmpty {
                emptyPreview
            } else {
                VStack(spacing: 10) {
                    ForEach(configs) { config in
                        HStack(spacing: 12) {
                            ProtocolChip(kind: config.kind, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(config.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(palette.text)
                                    .lineLimit(1)
                                Text(config.endpointDescription)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(palette.text2)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(palette.success)
                        }
                        .padding(13)
                        .nimbusCard(cornerRadius: 15, elevated: false)
                    }
                }
            }
        }
    }

    private var emptyPreview: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(palette.text3)
            Text("Go back and check the input.")
                .font(.system(size: 13))
                .foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .nimbusCard(cornerRadius: 16, elevated: false)
    }

    // MARK: - Shared bits

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(palette.text)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(palette.text2)
        }
        .padding(.bottom, 20)
    }
}

/// A wrapping row of selectable tag chips used on the review step.
private struct FlowTags: View {
    @Environment(\.palette) private var palette
    let tags: [String]
    let selected: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        // Two-column adaptive flow keeps this compiling on iOS 16 without Layout.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                let isSelected = selected.contains(tag)
                Button { onTap(tag) } label: {
                    Text(tag)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? palette.accent : palette.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? palette.accent.opacity(0.16) : palette.elev2)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(isSelected ? palette.accent.opacity(0.4) : palette.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#if DEBUG
struct CreateWizardView_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        CreateWizardView(app: model)
            .environmentObject(model)
            .nimbusPalette(model.palette)
    }
}
#endif
