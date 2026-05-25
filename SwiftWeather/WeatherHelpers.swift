import SwiftUI

// MARK: - Weather Icon Mapping (Pelmorex icon code → SF Symbol)

func weatherSymbol(for iconCode: Int) -> String {
    switch iconCode {
    case 1, 2:   return "sun.max.fill"
    case 3, 4:   return "cloud.sun.fill"
    case 5, 6:   return "cloud.fill"
    case 7, 8:   return "smoke.fill"
    case 9, 10:  return "cloud.drizzle.fill"
    case 11:     return "cloud.heavyrain.fill"
    case 12, 13: return "cloud.rain.fill"
    case 14, 15: return "cloud.snow.fill"
    case 16, 17: return "cloud.sleet.fill"
    case 18, 19, 20: return "cloud.snow.fill"
    case 21, 22, 23: return "cloud.bolt.rain.fill"
    case 24:     return "cloud.fog.fill"
    case 25:     return "snowflake"
    case 26:     return "wind"
    case 27:     return "moon.fill"
    case 28, 29: return "cloud.moon.rain.fill"
    case 30:     return "moon.stars.fill"
    case 31:     return "cloud.moon.fill"
    case 32, 33: return "cloud.snow.fill"
    default:     return "cloud.fill"
    }
}

// MARK: - Weather Symbol View

/// Renders a weather SF Symbol with contrast that adapts to both light and
/// dark card surfaces. `.multicolor` paints clouds/snow/fog with white
/// layers — fine on dark cards, invisible on white. We use palette mode
/// with theme-aware tints per-icon so the cloud body always reads.
struct WeatherSymbol: View {
    let icon: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = weatherIconPalette(for: icon, scheme: scheme)
        Image(systemName: weatherSymbol(for: icon))
            .symbolRenderingMode(.palette)
            .foregroundStyle(p.primary, p.secondary, p.tertiary)
    }
}

/// Per-icon palette tuned for visibility on white cards (light mode) and
/// dark cards (dark mode). Layer ordering follows SF Symbols' palette
/// preview: for multi-layer symbols the foreground/primary is the foremost
/// element (sun, drops, bolt, stars) and the secondary is the cloud body.
func weatherIconPalette(for iconCode: Int, scheme: ColorScheme) -> (primary: Color, secondary: Color, tertiary: Color) {
    let dark = scheme == .dark

    // Theme-aware palette anchors
    let cloud: Color = dark
        ? Color(red: 0.82, green: 0.86, blue: 0.92)   // light slate on dark
        : Color(red: 0.52, green: 0.59, blue: 0.70)   // medium slate on white
    let cloudShade: Color = dark
        ? Color(red: 0.70, green: 0.74, blue: 0.82)
        : Color(red: 0.42, green: 0.48, blue: 0.58)
    let sun = Color(red: 1.00, green: 0.72, blue: 0.12)
    let sunWarm = Color(red: 1.00, green: 0.52, blue: 0.16)
    let rain: Color = dark
        ? Color(red: 0.55, green: 0.78, blue: 1.00)
        : Color(red: 0.20, green: 0.52, blue: 0.95)
    let snow: Color = dark
        ? Color(red: 0.75, green: 0.90, blue: 1.00)
        : Color(red: 0.40, green: 0.68, blue: 0.92)
    let bolt = Color(red: 1.00, green: 0.78, blue: 0.18)
    let moon: Color = dark
        ? Color(red: 0.88, green: 0.88, blue: 0.96)
        : Color(red: 0.42, green: 0.42, blue: 0.62)
    let star = sun
    let fog: Color = dark
        ? Color(red: 0.85, green: 0.88, blue: 0.92)
        : Color(red: 0.62, green: 0.68, blue: 0.76)

    switch iconCode {
    case 1, 2:        return (sun, sunWarm, sun)                  // sun.max.fill
    case 3, 4:        return (sun, cloud, cloud)                  // cloud.sun.fill
    case 5, 6:        return (cloud, cloudShade, cloud)           // cloud.fill
    case 7, 8:        return (cloudShade, cloudShade, cloudShade) // smoke.fill
    case 9, 10:       return (rain, cloud, cloud)                 // cloud.drizzle.fill
    case 11:          return (rain, cloud, cloud)                 // cloud.heavyrain.fill
    case 12, 13:      return (rain, cloud, cloud)                 // cloud.rain.fill
    case 14, 15:      return (snow, cloud, cloud)                 // cloud.snow.fill
    case 16, 17:      return (snow, cloud, cloud)                 // cloud.sleet.fill
    case 18, 19, 20:  return (snow, cloud, cloud)                 // cloud.snow.fill
    case 21, 22, 23:  return (bolt, rain, cloud)                  // cloud.bolt.rain.fill
    case 24:          return (fog, cloud, cloud)                  // cloud.fog.fill
    case 25:          return (snow, snow, snow)                   // snowflake
    case 26:          return (cloudShade, cloudShade, cloudShade) // wind
    case 27:          return (moon, moon, moon)                   // moon.fill
    case 28, 29:      return (rain, moon, cloud)                  // cloud.moon.rain.fill
    case 30:          return (star, moon, moon)                   // moon.stars.fill
    case 31:          return (moon, cloud, cloud)                 // cloud.moon.fill
    case 32, 33:      return (snow, cloud, cloud)                 // cloud.snow.fill (night)
    default:          return (cloud, cloudShade, cloud)
    }
}

// MARK: - Background Gradient (day/night + condition aware)

func weatherGradient(for iconCode: Int) -> LinearGradient {
    let isNight = iconCode >= 27

    enum Condition { case clear, partlyCloudy, cloudy, rain, snow, storm, fog }

    let condition: Condition
    switch iconCode {
    case 1, 2, 27, 30:       condition = .clear
    case 3, 4, 31:           condition = .partlyCloudy
    case 5...8, 26:          condition = .cloudy
    case 9...13, 28, 29:     condition = .rain
    case 14...20, 25, 32, 33: condition = .snow
    case 21...23:            condition = .storm
    case 24:                 condition = .fog
    default:                 condition = .clear
    }

    let colors: [Color]
    if isNight {
        switch condition {
        case .clear:
            // Deep navy to dark indigo
            colors = [Color(red: 0.04, green: 0.06, blue: 0.20), Color(red: 0.08, green: 0.12, blue: 0.35)]
        case .partlyCloudy:
            // Dark blue-grey to navy
            colors = [Color(red: 0.08, green: 0.10, blue: 0.25), Color(red: 0.14, green: 0.18, blue: 0.38)]
        case .cloudy:
            // Dark grey to charcoal
            colors = [Color(red: 0.12, green: 0.14, blue: 0.20), Color(red: 0.20, green: 0.22, blue: 0.28)]
        case .rain:
            // Very dark slate to dark charcoal
            colors = [Color(red: 0.08, green: 0.10, blue: 0.18), Color(red: 0.16, green: 0.18, blue: 0.26)]
        case .snow:
            // Dark blue-grey to dark slate
            colors = [Color(red: 0.12, green: 0.15, blue: 0.25), Color(red: 0.22, green: 0.25, blue: 0.35)]
        case .storm:
            // Near-black purple to very dark grey
            colors = [Color(red: 0.06, green: 0.05, blue: 0.15), Color(red: 0.14, green: 0.12, blue: 0.22)]
        case .fog:
            // Dark grey to charcoal
            colors = [Color(red: 0.15, green: 0.16, blue: 0.20), Color(red: 0.25, green: 0.26, blue: 0.30)]
        }
    } else {
        switch condition {
        case .clear:
            // Light sky-blue to warm blue
            colors = [Color(red: 0.35, green: 0.65, blue: 0.95), Color(red: 0.22, green: 0.50, blue: 0.90)]
        case .partlyCloudy:
            // Muted sky-blue to soft blue
            colors = [Color(red: 0.42, green: 0.65, blue: 0.88), Color(red: 0.30, green: 0.52, blue: 0.82)]
        case .cloudy:
            // Muted grey-blue to grey
            colors = [Color(red: 0.55, green: 0.58, blue: 0.65), Color(red: 0.45, green: 0.48, blue: 0.55)]
        case .rain:
            // Slate blue-grey to steel grey
            colors = [Color(red: 0.38, green: 0.42, blue: 0.52), Color(red: 0.30, green: 0.35, blue: 0.45)]
        case .snow:
            // Cool white-blue to pale grey
            colors = [Color(red: 0.65, green: 0.72, blue: 0.82), Color(red: 0.52, green: 0.58, blue: 0.68)]
        case .storm:
            // Dark purple-grey to dark slate
            colors = [Color(red: 0.25, green: 0.22, blue: 0.35), Color(red: 0.18, green: 0.18, blue: 0.30)]
        case .fog:
            // Light grey to slightly darker grey
            colors = [Color(red: 0.62, green: 0.64, blue: 0.68), Color(red: 0.50, green: 0.52, blue: 0.58)]
        }
    }

    return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
}

/// Returns true when the weather gradient is light enough that text should be dark.
func isLightBackground(for iconCode: Int) -> Bool {
    let isNight = iconCode >= 27
    guard !isNight else { return false }
    // Daytime clear, partly cloudy, snow, and fog produce light gradients
    switch iconCode {
    case 1, 2, 3, 4:          return true  // clear, partly cloudy
    case 14...20, 25:          return true  // snow
    case 24:                   return true  // fog
    default:                   return false
    }
}

// MARK: - Date Formatting

private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private let localDateTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd'T'HH:mm"
    return f
}()

private let dateOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

private func parseDate(_ isoString: String) -> Date? {
    if let date = isoFormatter.date(from: isoString) { return date }
    if let date = localDateTimeFormatter.date(from: isoString) { return date }
    return dateOnlyFormatter.date(from: String(isoString.prefix(10)))
}

func formatHour(_ isoString: String) -> String {
    guard let date = parseDate(isoString) else { return isoString }
    let hour = Calendar.current.component(.hour, from: date)
    switch hour {
    case 0..<4:   return "Overnight"
    case 4..<10:  return "Morning"
    case 10..<16: return "Afternoon"
    case 16..<22: return "Evening"
    default:      return "Night"
    }
}

func isDifferentDay(_ time1: String, _ time2: String) -> Bool {
    guard let d1 = parseDate(time1), let d2 = parseDate(time2) else { return false }
    return !Calendar.current.isDate(d1, inSameDayAs: d2)
}

/// Returns the subset of `periods` whose start time is on the current local
/// calendar day AND strictly after "now". Used by the Today's Overview card
/// so the summary only describes periods that are still ahead — e.g. at
/// 11:30 AM on a day with Overnight / Morning / Afternoon / Evening periods,
/// this returns just Afternoon and Evening.
func todayPeriodsAfterNow(_ periods: [HourlyPeriod], now: Date = Date()) -> [HourlyPeriod] {
    let cal = Calendar.current
    return periods.filter { p in
        guard let date = parseDate(p.timeLocal) else { return false }
        return cal.isDate(date, inSameDayAs: now) && date > now
    }
}

func formatDayShort(_ isoString: String) -> String {
    guard let date = parseDate(isoString) else { return "" }
    if Calendar.current.isDateInToday(date) { return "TODAY" }
    if Calendar.current.isDateInTomorrow(date) { return "TOMORROW" }
    let f = DateFormatter()
    f.dateFormat = "EEE"
    return f.string(from: date).uppercased()
}

func formatDay(_ isoString: String) -> String {
    guard let date = parseDate(isoString) else { return isoString }
    let cal = Calendar.current
    if cal.isDateInToday(date) { return "Today" }
    if cal.isDateInTomorrow(date) { return "Tomorrow" }
    let f = DateFormatter()
    f.dateFormat = "EEE, MMM d"
    return f.string(from: date)
}

func formatTime(_ isoString: String) -> String {
    guard let date = parseDate(isoString) else { return isoString }
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f.string(from: date)
}

// MARK: - UV Color

func uvColor(for index: Int) -> Color {
    switch index {
    case 0...2:  return .green
    case 3...5:  return .yellow
    case 6...7:  return .orange
    case 8...10: return .red
    default:     return .purple
    }
}

// MARK: - Wind Direction Arrow

func windDirectionDegrees(_ direction: String) -> Double {
    let map: [String: Double] = [
        "N": 180, "NNE": 202.5, "NE": 225, "ENE": 247.5,
        "E": 270, "ESE": 292.5, "SE": 315, "SSE": 337.5,
        "S": 0, "SSW": 22.5, "SW": 45, "WSW": 67.5,
        "W": 90, "WNW": 112.5, "NW": 135, "NNW": 157.5,
    ]
    return map[direction] ?? 0
}
