import SwiftUI

// MARK: - Palette

/// Shared visual tokens for the Carrot-inspired redesign. Solid white pill
/// cards on a cool-grey background in light mode, deep slate cards on near-
/// black in dark mode.
enum CarrotStyle {
    // MARK: Backgrounds

    static func screenBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.07, green: 0.08, blue: 0.10)
            : Color(red: 0.93, green: 0.94, blue: 0.96)
    }

    static func cardSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.13, green: 0.14, blue: 0.16)
            : .white
    }

    static func cardShadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? .black.opacity(0.45)
            : Color(red: 0.36, green: 0.42, blue: 0.55).opacity(0.10)
    }

    // MARK: Accents

    static let accent = Color(red: 0.13, green: 0.45, blue: 0.96)        // Carrot's primary blue
    static let accentSoft = Color(red: 0.13, green: 0.45, blue: 0.96).opacity(0.12)
    static let alertRed = Color(red: 0.92, green: 0.32, blue: 0.36)
    static let alertOrange = Color(red: 0.96, green: 0.55, blue: 0.20)
    static let alertYellow = Color(red: 0.95, green: 0.72, blue: 0.18)

    static let precipBlue = Color(red: 0.30, green: 0.62, blue: 1.00)

    // MARK: Metrics

    static let cardCornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let cardShadowRadius: CGFloat = 12
    static let cardShadowY: CGFloat = 3
}

// MARK: - Card Modifier

private struct CarrotCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = CarrotStyle.cardCornerRadius
    var padding: CGFloat? = CarrotStyle.cardPadding

    func body(content: Content) -> some View {
        Group {
            if let padding {
                content.padding(padding)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(CarrotStyle.cardSurface(colorScheme))
        )
        .shadow(
            color: CarrotStyle.cardShadow(colorScheme),
            radius: CarrotStyle.cardShadowRadius,
            x: 0,
            y: CarrotStyle.cardShadowY
        )
    }
}

extension View {
    /// Applies the Carrot-style card surface (white/dark fill, rounded, subtle
    /// shadow). Pass `padding: nil` if the receiver manages its own padding.
    func carrotCard(cornerRadius: CGFloat = CarrotStyle.cardCornerRadius,
                    padding: CGFloat? = CarrotStyle.cardPadding) -> some View {
        modifier(CarrotCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Section Header

struct CarrotSectionHeader: View {
    let title: String
    let systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Temperature Gradient

/// Maps an absolute temperature in Celsius onto a perceptual hue band ranging
/// from cold blue → green → yellow → orange → red. Used by the daily forecast
/// rows so the bar colour is comparable across days, not relative to today's
/// range.
func temperatureColor(forCelsius t: Double) -> Color {
    let stops: [(Double, Color)] = [
        (-30, Color(red: 0.45, green: 0.55, blue: 0.95)),
        (-10, Color(red: 0.35, green: 0.70, blue: 0.95)),
        (  0, Color(red: 0.30, green: 0.80, blue: 0.85)),
        ( 10, Color(red: 0.45, green: 0.85, blue: 0.45)),
        ( 18, Color(red: 0.95, green: 0.85, blue: 0.20)),
        ( 25, Color(red: 0.98, green: 0.60, blue: 0.18)),
        ( 32, Color(red: 0.96, green: 0.35, blue: 0.22)),
        ( 40, Color(red: 0.88, green: 0.15, blue: 0.25)),
    ]
    if t <= stops.first!.0 { return stops.first!.1 }
    if t >= stops.last!.0  { return stops.last!.1 }
    for i in 0..<(stops.count - 1) {
        let (lo, loColor) = stops[i]
        let (hi, hiColor) = stops[i + 1]
        if t >= lo, t <= hi {
            let f = (t - lo) / (hi - lo)
            return loColor.blend(with: hiColor, fraction: f)
        }
    }
    return stops.last!.1
}

private extension Color {
    /// Linear blend between two colors. Kept private — only used by the
    /// temperatureColor stop interpolation.
    func blend(with other: Color, fraction: Double) -> Color {
        #if canImport(UIKit)
        let a = UIColor(self).cgColor.components ?? [0,0,0,1]
        let b = UIColor(other).cgColor.components ?? [0,0,0,1]
        #else
        let a = NSColor(self).usingColorSpace(.deviceRGB)?.cgColor.components ?? [0,0,0,1]
        let b = NSColor(other).usingColorSpace(.deviceRGB)?.cgColor.components ?? [0,0,0,1]
        #endif
        func mix(_ i: Int) -> Double {
            let av = Double(a.count > i ? a[i] : 0)
            let bv = Double(b.count > i ? b[i] : 0)
            return av + (bv - av) * fraction
        }
        return Color(red: mix(0), green: mix(1), blue: mix(2)).opacity(mix(3))
    }
}
