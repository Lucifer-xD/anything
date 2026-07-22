import SwiftUI

extension Color {
    /// Creates a color from a `#RRGGBB` / `#RRGGBBAA` / `#RGB` hex string.
    /// Invalid strings fall back to clear so a bad token never crashes the UI.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 3: // RGB (12-bit)
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
            a = 1
        case 6: // RRGGBB
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        case 8: // RRGGBBAA
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Blend the receiver toward `other` by `amount` (0…1) — the SwiftUI analogue
    /// of the design's `color-mix(in srgb, …)` usage.
    func mix(with other: Color, amount: Double) -> Color {
        let a = amount.clamped(to: 0...1)
        #if canImport(UIKit)
        let c1 = UIColor(self), c2 = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(.sRGB,
                     red: Double(r1 + (r2 - r1) * a),
                     green: Double(g1 + (g2 - g1) * a),
                     blue: Double(b1 + (b2 - b1) * a),
                     opacity: Double(a1 + (a2 - a1) * a))
        #else
        return self
        #endif
    }

    /// A translucent tint of the receiver (design's `color-mix(accent X%, transparent)`).
    func tinted(_ percent: Double) -> Color { opacity(percent / 100) }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
