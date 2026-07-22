import SwiftUI
import NimbusKit

/// The three appearance modes from the design (`data-theme`).
public enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case dark, amoled, light
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .dark: return "Dark"
        case .amoled: return "AMOLED"
        case .light: return "Light"
        }
    }
    /// Cycle order used by the header theme button.
    public var next: AppTheme {
        switch self {
        case .dark: return .light
        case .light: return .amoled
        case .amoled: return .dark
        }
    }
    var colorScheme: ColorScheme { self == .light ? .light : .dark }
}

/// The six accent colors from the design's `ACCENTS` map.
public enum AppAccent: String, CaseIterable, Codable, Identifiable {
    case blue, indigo, green, purple, teal, orange
    public var id: String { rawValue }
    var hex: String {
        switch self {
        case .blue: return "#0A84FF"
        case .indigo: return "#5E5CE6"
        case .green: return "#30D158"
        case .purple: return "#BF5AF2"
        case .teal: return "#64D2FF"
        case .orange: return "#FF9F0A"
        }
    }
    var color: Color { Color(hex: hex) }
}

/// Semantic color palette for a given theme + accent, ported 1:1 from the design's
/// CSS custom properties (`--bg`, `--elev1`, `--text2`, …). Injected through the
/// environment so every view reads the same tokens.
public struct NimbusPalette {
    public let theme: AppTheme
    public let accent: Color

    public init(theme: AppTheme, accent: AppAccent) {
        self.theme = theme
        self.accent = accent.color
    }

    // Backgrounds & surfaces
    public var bg: Color {
        switch theme {
        case .dark: return Color(hex: "#0b0b0d")
        case .amoled: return Color(hex: "#000000")
        case .light: return Color(hex: "#eef0f4")
        }
    }
    public var elev1: Color {
        switch theme {
        case .dark: return Color(hex: "#151517")
        case .amoled: return Color.white.opacity(0.045)
        case .light: return Color(hex: "#ffffff")
        }
    }
    public var elev2: Color {
        switch theme {
        case .dark: return Color(hex: "#1d1d20")
        case .amoled: return Color.white.opacity(0.08)
        case .light: return Color(hex: "#ffffff")
        }
    }
    public var border: Color {
        switch theme {
        case .light: return Color.black.opacity(0.07)
        case .amoled: return Color.white.opacity(0.08)
        case .dark: return Color.white.opacity(0.09)
        }
    }
    public var divider: Color {
        switch theme {
        case .light: return Color.black.opacity(0.055)
        case .amoled: return Color.white.opacity(0.05)
        case .dark: return Color.white.opacity(0.06)
        }
    }
    public var console: Color {
        switch theme {
        case .light: return Color(hex: "#16161a")
        case .amoled: return Color(hex: "#000000")
        case .dark: return Color(hex: "#08080a")
        }
    }
    public var inputBg: Color {
        switch theme {
        case .light: return Color.black.opacity(0.04)
        default: return Color.black.opacity(0.35)
        }
    }
    public var barBg: Color {
        switch theme {
        case .light: return Color(hex: "#f8f8fa").opacity(0.82)
        default: return Color(hex: "#121214").opacity(0.72)
        }
    }

    // Text
    public var text: Color { theme == .light ? Color(hex: "#1c1c1e") : Color.white }
    public var text2: Color {
        theme == .light ? Color(hex: "#3c3c43").opacity(0.62) : Color(hex: "#ebebf5").opacity(0.6)
    }
    public var text3: Color {
        theme == .light ? Color(hex: "#3c3c43").opacity(0.32) : Color(hex: "#ebebf5").opacity(0.32)
    }

    // Fixed status colors (identical across themes)
    public var success: Color { Color(hex: "#30D158") }
    public var warning: Color { Color(hex: "#FF9F0A") }
    public var danger: Color { Color(hex: "#FF453A") }
    public var info: Color { accent }

    public var shadow: Color {
        theme == .light ? Color.black.opacity(0.18) : Color.black.opacity(0.6)
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = NimbusPalette(theme: .dark, accent: .blue)
}

public extension EnvironmentValues {
    var palette: NimbusPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

public extension View {
    /// Inject a palette and apply its color scheme + background to a subtree.
    func nimbusPalette(_ palette: NimbusPalette) -> some View {
        environment(\.palette, palette)
            .preferredColorScheme(palette.theme.colorScheme)
            .tint(palette.accent)
    }
}

/// Convenience: map a `ProtocolKind`'s tint hex to a `Color`.
public extension ProtocolKind {
    var tint: Color { Color(hex: metadata.tintHex) }
}
