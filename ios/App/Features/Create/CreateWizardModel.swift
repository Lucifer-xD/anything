import SwiftUI
import NimbusKit

/// State machine for the multi-step Create wizard. Two paths, mirroring the
/// design: an **import** path (Source → Input → Preview) and a **manual/template**
/// path (Source → Protocol → Configure → Review).
@MainActor
final class CreateWizardModel: ObservableObject {
    enum Method: String, CaseIterable, Identifiable {
        case qr, clipboard, url, file, manual, template
        var id: String { rawValue }
        var isImport: Bool { [.qr, .clipboard, .url, .file].contains(self) }
    }

    @Published var method: Method?
    @Published var step: Int = 0
    @Published var selectedProtocol: ProtocolKind = .reality
    @Published var fields = ConfigFields()
    @Published var tags: Set<String> = []
    @Published var inputText = ""
    @Published var treatAsSubscription = true
    @Published var previewResult: ImportResult?
    @Published var isBusy = false

    private unowned let app: AppModel
    init(app: AppModel) { self.app = app }

    // Derived
    var isImport: Bool { method?.isImport ?? false }
    var stepCount: Int { isImport ? 3 : 4 }
    var lastStep: Int { stepCount - 1 }
    var stepLabels: [String] { isImport ? ["Source", "Input", "Preview"] : ["Source", "Protocol", "Configure", "Review"] }
    var stepLabel: String { "\(stepLabels[min(step, stepLabels.count - 1)]) · \(step + 1) of \(stepCount)" }
    var schema: [FieldSection] { selectedProtocol.fieldSchema }
    var protocols: [ProtocolKind] { ProtocolRegistry.shared.registeredKinds }
    var allTags: [String] { ["Streaming", "Gaming", "Torrent", "Work", "Privacy"] }

    var isMethodStep: Bool { step == 0 }
    var isProtocolStep: Bool { !isImport && step == 1 }
    var isConfigureStep: Bool { !isImport && step == 2 }
    var isReviewStep: Bool { !isImport && step == 3 }
    var isInputStep: Bool { isImport && step == 1 }
    var isPreviewStep: Bool { isImport && step == 2 }

    var nextTitle: String {
        step >= lastStep ? (isImport ? "Import Selected" : "Save Configuration") : "Continue"
    }
    var reviewName: String { fields.string(FieldKey.name) ?? "New \(selectedProtocol.metadata.displayName)" }

    // MARK: Intents

    func select(_ method: Method) {
        self.method = method
        step = 1
        if !method.isImport {
            selectedProtocol = method == .manual ? .reality : app.settings.defaultProtocol
            seedDefaults()
        }
    }

    func selectProtocol(_ kind: ProtocolKind) {
        selectedProtocol = kind
        seedDefaults()
    }

    /// Advance; returns a saved config id when the wizard completes a manual save.
    @discardableResult
    func next() async -> UUID? {
        if step >= lastStep {
            return await commit()
        }
        if isProtocolStep && fields.isEmpty { seedDefaults() }
        if isInputStep { await runImport() }
        step += 1
        return nil
    }

    func back() {
        if step == 0 { return }
        step -= 1
    }

    func toggleTag(_ tag: String) {
        if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
    }

    func pasteFromClipboard() {
        #if canImport(UIKit)
        inputText = UIPasteboard.general.string ?? inputText
        #endif
    }

    private func seedDefaults() {
        fields.applyDefaults(schema.defaultValues)
    }

    private func runImport() async {
        isBusy = true
        previewResult = app.services.importer.import(inputText, source: importSource)
        isBusy = false
    }

    private var importSource: ConfigSource {
        switch method {
        case .qr: return .qr
        case .clipboard: return .clipboard
        case .url: return .url
        case .file: return .file
        default: return .manual
        }
    }

    /// Build the configuration from the form.
    func buildConfig() -> TunnelConfiguration {
        var meta = ConfigMetadata(group: fields.string(FieldKey.group) ?? "Personal",
                                  tags: Array(tags),
                                  source: method == .template ? .template : .manual)
        if let folder = app.folders.first(where: { $0.name == meta.group }) { meta.folderID = folder.id }
        return TunnelConfiguration(kind: selectedProtocol, fields: fields, metadata: meta)
    }

    @discardableResult
    private func commit() async -> UUID? {
        if isImport {
            if let configs = previewResult?.configs, !configs.isEmpty {
                try? await app.services.store.importConfigurations(configs)
            }
            return nil
        } else {
            let config = buildConfig()
            let saved = try? await app.services.store.save(config)
            return saved?.id
        }
    }
}
