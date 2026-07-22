import SwiftUI
import NimbusKit

// MARK: - Surfaces

/// The standard elevated card surface used across the app.
struct CardBackground: ViewModifier {
    @Environment(\.palette) private var palette
    var elevated: Bool = true
    var cornerRadius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(palette.elev1)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 1)
            )
            .shadow(color: elevated ? palette.shadow.opacity(0.5) : .clear, radius: 18, x: 0, y: 10)
    }
}

extension View {
    func nimbusCard(cornerRadius: CGFloat = 18, elevated: Bool = true) -> some View {
        modifier(CardBackground(elevated: elevated, cornerRadius: cornerRadius))
    }
}

/// A titled group with the small uppercase caption above a rounded container —
/// the app's most repeated layout (Settings, Detail, Editor sections).
struct SectionLabel: View {
    @Environment(\.palette) private var palette
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(palette.text3)
            .padding(.horizontal, 4)
    }
}

// MARK: - Buttons

/// The big accent CTA (Connect, Continue, Save) with the accent glow shadow.
struct PrimaryButton: View {
    @Environment(\.palette) private var palette
    let title: String
    var systemImage: String? = nil
    var role: Role = .accent
    let action: () -> Void

    enum Role { case accent, destructive, neutral }

    private var background: Color {
        switch role {
        case .accent: return palette.accent
        case .destructive: return palette.danger.opacity(0.16)
        case .neutral: return palette.elev2
        }
    }
    private var foreground: Color {
        switch role {
        case .accent: return .white
        case .destructive: return palette.danger
        case .neutral: return palette.text
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: role == .accent ? palette.accent.opacity(0.45) : .clear, radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

/// A small pill button used for quick actions.
struct GhostButton: View {
    @Environment(\.palette) private var palette
    let title: String
    var systemImage: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
            .foregroundStyle(palette.text)
            .background(palette.elev2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Protocol & status affordances

/// The rounded-square protocol chip with the two-letter abbreviation.
struct ProtocolChip: View {
    let kind: ProtocolKind
    var size: CGFloat = 40
    var body: some View {
        let tint = kind.tint
        Text(kind.metadata.abbreviation)
            .font(.system(size: size * 0.33, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

/// The colored required / advanced / experimental badge in the editor.
struct LevelBadge: View {
    @Environment(\.palette) private var palette
    let level: FieldLevel
    var body: some View {
        if let title = level.badgeTitle {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
    private var color: Color {
        switch level {
        case .required: return palette.warning
        case .advanced: return palette.accent
        case .experimental: return Color(hex: "#BF5AF2")
        case .optional: return palette.text3
        }
    }
}

/// A latency pill (colored dot + `27 ms`). Green < 50, amber < 100, red otherwise.
struct LatencyPill: View {
    @Environment(\.palette) private var palette
    let milliseconds: Int?
    var body: some View {
        let color = Self.color(for: milliseconds, palette: palette)
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(milliseconds.map { "\($0) ms" } ?? "—")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(palette.elev2)
        .clipShape(Capsule())
    }
    static func color(for ms: Int?, palette: NimbusPalette) -> Color {
        guard let ms else { return palette.text3 }
        return ms < 50 ? palette.success : (ms < 100 ? palette.warning : palette.danger)
    }
}

/// A small text tag chip (transport, traffic, etc.).
struct TagChip: View {
    @Environment(\.palette) private var palette
    let text: String
    var tint: Color? = nil
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint ?? palette.text2)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background((tint ?? palette.text2).opacity(tint == nil ? 0 : 0.14))
            .background(tint == nil ? palette.elev2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// A selectable filter / choice chip.
struct ChoiceChip: View {
    @Environment(\.palette) private var palette
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : palette.text2)
                .padding(.horizontal, 15).padding(.vertical, 8)
                .background(isSelected ? palette.accent : palette.elev2)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? palette.accent : palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// The rounded search field header row.
struct SearchField: View {
    @Environment(\.palette) private var palette
    @Binding var text: String
    var placeholder: String = "Search configs, servers, tags"
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.text2)
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .foregroundStyle(palette.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(palette.elev2)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(palette.border, lineWidth: 1))
    }
}

/// A large screen title (`Configurations`, `Settings`).
struct ScreenTitle: View {
    @Environment(\.palette) private var palette
    let title: String
    var eyebrow: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(palette.text3)
            }
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(palette.text)
        }
    }
}

/// A back button that reads "‹ Label" in the accent color.
struct BackButton: View {
    @Environment(\.palette) private var palette
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                Text(label).font(.system(size: 17))
            }
            .foregroundStyle(palette.accent)
        }
        .buttonStyle(.plain)
    }
}
