import SwiftUI
import NimbusKit

/// The Subscriptions tab: manages remote configuration sources (base64 node
/// lists refreshed on a schedule). Implements the design's SUBSCRIPTIONS section
/// — an add-source header, an auto-update card, an "Update All" refresh action,
/// and a list of subscription cards with node/expiry/traffic chips.
struct SubscriptionsScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    autoUpdateCard
                    updateAllButton

                    if model.subscriptions.isEmpty {
                        emptyState
                            .padding(.top, 10)
                    } else {
                        LazyVStack(spacing: 11) {
                            ForEach(model.subscriptions) { sub in
                                SubscriptionCard(subscription: sub)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            model.deleteSubscription(sub.id)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 108)
            }
            .background(palette.bg.ignoresSafeArea())
            .toolbar(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showingAdd) {
            AddSubscriptionSheet { sub in
                model.addSubscription(sub)
            }
            .nimbusPalette(palette)
            .environmentObject(model)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            ScreenTitle(title: "Subscriptions")
            Spacer(minLength: 12)
            Button {
                showingAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(palette.accent)
                    .clipShape(Circle())
                    .shadow(color: palette.accent.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add subscription")
        }
    }

    // MARK: - Auto-update card

    private var autoUpdateCard: some View {
        HStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Auto-update all")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(autoUpdateSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text2)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $model.settings.autoUpdateSubscriptions)
                .labelsHidden()
                .tint(palette.accent)
        }
        .padding(15)
        .nimbusCard()
    }

    private var autoUpdateSubtitle: String {
        var parts = ["Refresh every 6 hours"]
        if let latest = model.subscriptions.compactMap(\.lastUpdated).max() {
            parts.append("last \(Self.relative.localizedString(for: latest, relativeTo: Date()))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Update All

    private var updateAllButton: some View {
        Button {
            model.refreshSubscriptions()
        } label: {
            HStack(spacing: 9) {
                if model.isRefreshingSubscriptions {
                    ProgressView()
                        .controlSize(.small)
                        .tint(palette.accent)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
                Text(model.isRefreshingSubscriptions ? "Updating…" : "Update All")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(palette.elev2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(model.isRefreshingSubscriptions)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(palette.text3)
            Text("No subscriptions")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.text)
            Text("Add a subscription URL to auto-import nodes from your provider.")
                .font(.system(size: 14))
                .foregroundStyle(palette.text2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
        .nimbusCard()
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

// MARK: - Subscription card

private struct SubscriptionCard: View {
    @Environment(\.palette) private var palette
    let subscription: Subscription

    private var tint: Color { Color(hex: subscription.tintHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                Image(systemName: "globe")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    Text(subscription.url.absoluteString)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.text3)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            FlowChips(chips: chips)
        }
        .padding(15)
        .nimbusCard()
    }

    private var chips: [SubscriptionChip] {
        var result: [SubscriptionChip] = [
            .init(text: "\(subscription.nodeCount) nodes", color: palette.accent, filled: true)
        ]
        result.append(.init(text: "Updated \(updatedText)", color: palette.text2, filled: false))
        if let expiryText {
            result.append(.init(text: expiryText, color: expiryColor, filled: false))
        }
        if let trafficText {
            result.append(.init(text: trafficText, color: palette.text2, filled: false))
        }
        return result
    }

    private var updatedText: String {
        guard let lastUpdated = subscription.lastUpdated else { return "never" }
        return Self.relative.localizedString(for: lastUpdated, relativeTo: Date())
    }

    private var expiryText: String? {
        guard let expiresAt = subscription.expiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
        if expiresAt <= Date() { return "Expired" }
        if days <= 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }

    private var expiryColor: Color {
        guard let expiresAt = subscription.expiresAt else { return palette.text2 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
        return (expiresAt <= Date() || days < 7) ? palette.warning : palette.text2
    }

    private var trafficText: String? {
        guard let used = subscription.usedBytes, let total = subscription.totalBytes else { return nil }
        return "\(ByteFormat.short(used)) / \(ByteFormat.short(total))"
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

private struct SubscriptionChip: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
    let filled: Bool
}

/// A simple wrapping chip row so long chip sets flow onto multiple lines.
private struct FlowChips: View {
    @Environment(\.palette) private var palette
    let chips: [SubscriptionChip]

    var body: some View {
        FlowLayout(spacing: 7, lineSpacing: 7) {
            ForEach(chips) { chip in
                Text(chip.text)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(chip.color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(chip.filled ? chip.color.opacity(0.12) : palette.elev2)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
    }
}

/// A minimal flow layout (leading-aligned, wraps to available width) for iOS 16.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 7
    var lineSpacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows = arrange(subviews: subviews, maxWidth: maxWidth)
        let height = rows.isEmpty ? 0 : rows.last!.maxY
        rows.removeAll()
        return CGSize(width: maxWidth == .infinity ? 0 : maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = arrange(subviews: subviews, maxWidth: bounds.width)
        for item in rows {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + item.y),
                proposal: ProposedViewSize(item.size)
            )
        }
    }

    private struct Item { let index: Int; let x: CGFloat; let y: CGFloat; let size: CGSize; var maxY: CGFloat { y + size.height } }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Item] {
        var items: [Item] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            items.append(Item(index: index, x: x, y: y, size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return items
    }
}

// MARK: - Add subscription sheet

private struct AddSubscriptionSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    let onAdd: (Subscription) -> Void

    @State private var name = ""
    @State private var urlString = ""

    private var trimmedURL: String { urlString.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var parsedURL: URL? {
        guard let url = URL(string: trimmedURL), url.scheme != nil, url.host != nil else { return nil }
        return url
    }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedURL != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 9) {
                        SectionLabel(title: "NAME")
                        fieldContainer {
                            TextField("My Provider", text: $name)
                                .font(.system(size: 16))
                                .foregroundStyle(palette.text)
                                .textInputAutocapitalization(.words)
                        }
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        SectionLabel(title: "SUBSCRIPTION URL")
                        fieldContainer {
                            TextField("https://example.com/sub", text: $urlString)
                                .font(.system(size: 16))
                                .foregroundStyle(palette.text)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Text("A URL returning a base64 list of share-links. New nodes refresh on schedule.")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.text3)
                            .padding(.horizontal, 4)
                    }

                    PrimaryButton(title: "Add Subscription", systemImage: "plus") {
                        guard let url = parsedURL else { return }
                        let cleanName = name.trimmingCharacters(in: .whitespaces)
                        onAdd(Subscription(name: cleanName, url: url))
                        dismiss()
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
            .background(palette.bg.ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                HStack {
                    Text("New Subscription")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(palette.text)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.text2)
                            .frame(width: 30, height: 30)
                            .background(palette.elev2)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(palette.bg)
            }
            .toolbar(.hidden)
        }
    }

    private func fieldContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(palette.elev1)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(palette.border, lineWidth: 1))
    }
}

#if DEBUG
struct SubscriptionsScreen_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(services: .makeSimulated())
        return SubscriptionsScreen()
            .environmentObject(model)
            .nimbusPalette(model.palette)
    }
}
#endif
