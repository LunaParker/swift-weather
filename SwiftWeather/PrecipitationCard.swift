import SwiftUI
import FoundationModels

struct PrecipitationCard: View {
    let hourly: [HourlyPeriod]
    let daily: [DailyForecast]

    @AppStorage("unitSystem") private var unitSystem: String = "metric"
    @AppStorage("precipThreshold") private var precipThreshold: Int = 40

    @State private var aiSummary: String?
    @State private var isGenerating = false
    @State private var hoveredIndex: Int?

    private var today: DailyForecast? { daily.first }
    private var todayPeriods: [HourlyPeriod] { Array(hourly.prefix(4)) }
    private var maxPop: Int { todayPeriods.map(\.pop).max() ?? today?.day.pop ?? 0 }
    private var totalRain: Double { today?.totalRain.value ?? 0 }
    private var totalSnow: Double { today?.totalSnow.value ?? 0 }
    private var rainUnit: String { unitSystem == "imperial" ? "in" : "mm" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Heading: umbrella + Carrot-style headline sentence
            HStack(spacing: 8) {
                Image(systemName: headlineIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CarrotStyle.precipBlue)
                Text(headlineText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                if isGenerating {
                    ProgressView().controlSize(.small)
                }
            }

            // AI / fallback explanatory sentence (smaller, secondary)
            if let summary = aiSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .blurReplace))
            }

            // Bar chart
            precipitationChart
                .frame(height: 92)

            // Details
            if maxPop > 0 {
                detailsRow
                    .padding(.top, 2)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: aiSummary != nil)
        .animation(.easeInOut(duration: 0.3), value: isGenerating)
        .carrotCard()
        .task(id: precipDataID) {
            await generateAISummary()
        }
    }

    // MARK: - Carrot-style headline

    private var headlineIcon: String {
        if totalSnow > 0 { return "snowflake" }
        if maxPop >= precipThreshold { return "umbrella.fill" }
        return "umbrella"
    }

    private var headlineText: String {
        let threshold = precipThreshold
        if maxPop < threshold {
            return "No Precipitation Expected"
        }
        let isCurrentlyPrecip = todayPeriods.first.map { $0.pop >= threshold } ?? false
        if isCurrentlyPrecip {
            if let stopPeriod = todayPeriods.dropFirst().first(where: { $0.pop < threshold }) {
                return "Rain Easing by \(formatHour(stopPeriod.timeLocal))"
            }
            return "Rain Through the Day"
        } else if let startPeriod = todayPeriods.first(where: { $0.pop >= threshold }) {
            return "Rain Likely \(formatHour(startPeriod.timeLocal))"
        }
        return "\(maxPop)% Chance of Rain"
    }

    // MARK: - AI Summary

    private var precipDataID: String {
        let pops = todayPeriods.map { "\($0.pop)" }.joined(separator: ",")
        let rain = String(format: "%.1f", totalRain)
        let snow = String(format: "%.1f", totalSnow)
        return "\(pops)|\(rain)|\(snow)"
    }

    private func generateAISummary() async {
        guard SystemLanguageModel.default.availability == .available else { return }

        isGenerating = true
        defer { isGenerating = false }

        let prompt = buildPrecipPrompt()

        do {
            let session = LanguageModelSession {
                """
                STRICT RULES — you must follow ALL of these:
                1. Respond with EXACTLY ONE plain-text sentence. No more.
                2. NEVER use bullet points, asterisks, lists, line breaks, or Markdown of any kind.
                3. Keep it under 25 words.
                4. If precipitation meets the threshold, mention the peak probability and timing.
                5. If no precipitation meets the threshold, say none is expected.
                Example good responses:
                "70% chance of rain starting in the afternoon and continuing overnight."
                "Showers likely through the morning with a peak 90% chance, tapering off by evening."
                "No precipitation expected today."
                """
            }
            let response = try await session.respond(to: prompt)
            var text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            text = text.replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "* ", with: "")
                .replacingOccurrences(of: "- ", with: "")
            if let firstLine = text.components(separatedBy: .newlines).first(where: { !$0.isEmpty }) {
                text = firstLine
            }
            if !text.isEmpty {
                withAnimation(.easeIn(duration: 0.4)) {
                    aiSummary = text
                }
            }
        } catch {
            // Silently fall back to template text
        }
    }

    private func buildPrecipPrompt() -> String {
        let threshold = precipThreshold
        var lines: [String] = []
        lines.append("Summarize TODAY ONLY precipitation outlook in one sentence from this data:")
        lines.append("Precipitation threshold (minimum to count as likely): \(threshold)%")

        let isCurrentlyPrecip = todayPeriods.first.map { $0.pop >= threshold } ?? false
        lines.append("Currently precipitating: \(isCurrentlyPrecip ? "YES" : "NO")")

        for period in todayPeriods {
            let meetsThreshold = period.pop >= threshold ? " [MEETS THRESHOLD]" : ""
            lines.append("Period \(formatHour(period.timeLocal)): POP \(period.pop)%\(meetsThreshold), Rain \(String(format: "%.1f", period.rain.value))\(rainUnit), Snow \(String(format: "%.1f", period.snow.value))cm")
        }

        if let today {
            lines.append("Day POP: \(today.day.pop)%, Night POP: \(today.night.pop)%")
            lines.append("Total rain today: \(String(format: "%.1f", totalRain))\(rainUnit), Total snow today: \(String(format: "%.1f", totalSnow))cm")
        }

        lines.append("Max POP today: \(maxPop)%")
        return lines.joined(separator: "\n")
    }

    // MARK: - Bar Chart

    private var precipitationChart: some View {
        GeometryReader { geo in
            let periods = Array(hourly.prefix(8))
            let barCount = periods.count
            guard barCount > 0 else { return AnyView(EmptyView()) }

            let spacing: CGFloat = 4
            let totalSpacing = spacing * CGFloat(barCount - 1)
            let barWidth = (geo.size.width - totalSpacing) / CGFloat(barCount)

            return AnyView(
                VStack(spacing: 6) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                            precipBarView(period: period, index: index, maxHeight: geo.size.height - 22, width: barWidth)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)

                    HStack(spacing: spacing) {
                        ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                            Text(shortPeriodLabel(period.timeLocal))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(hoveredIndex == index ? .primary : .secondary)
                                .frame(width: barWidth)
                        }
                    }
                }
            )
        }
    }

    private func precipBarView(period: HourlyPeriod, index: Int, maxHeight: CGFloat, width: CGFloat) -> some View {
        let fraction = CGFloat(period.pop) / 100.0
        let minBarHeight: CGFloat = 3
        let barHeight = max(minBarHeight, maxHeight * fraction)
        let isHovered = hoveredIndex == index

        return RoundedRectangle(cornerRadius: 4)
            .fill(precipBarColor(pop: period.pop, hovered: isHovered))
            .frame(width: width, height: period.pop > 0 ? barHeight : minBarHeight)
            .overlay(alignment: .top) {
                if isHovered {
                    precipTooltip(for: period)
                        .offset(y: -4)
                        .transition(.opacity)
                }
            }
            .onHover { over in
                withAnimation(.easeOut(duration: 0.15)) {
                    hoveredIndex = over ? index : nil
                }
            }
    }

    private func precipTooltip(for period: HourlyPeriod) -> some View {
        let hasRain = period.rain.value > 0
        let hasSnow = period.snow.value > 0
        let precipType: String = if hasRain && hasSnow { "Mixed" }
            else if hasSnow { "Snow" }
            else if hasRain { "Rain" }
            else if period.pop > 0 { "Rain" }
            else { "" }

        return VStack(alignment: .leading, spacing: 3) {
            Text("\(period.pop)%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CarrotStyle.precipBlue)

            if !precipType.isEmpty {
                Text(precipType)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }

            if hasRain {
                Text(String(format: "%.1f %@", period.rain.value, rainUnit))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if hasSnow {
                Text(String(format: "%.1f %@", period.snow.value, unitSystem == "imperial" ? "in" : "cm"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .fixedSize()
        .offset(y: -56)
    }

    private func precipBarColor(pop: Int, hovered: Bool = false) -> Color {
        if hovered { return CarrotStyle.precipBlue }
        switch pop {
        case 0:       return Color.secondary.opacity(0.12)
        case 1..<30:  return CarrotStyle.precipBlue.opacity(0.35)
        case 30..<60: return CarrotStyle.precipBlue.opacity(0.6)
        case 60..<80: return CarrotStyle.precipBlue.opacity(0.8)
        default:      return CarrotStyle.precipBlue
        }
    }

    // MARK: - Details Row

    private var detailsRow: some View {
        HStack(spacing: 24) {
            metric(label: "Chance", value: "\(maxPop)%", tint: CarrotStyle.precipBlue)

            if totalRain > 0 {
                metric(label: "Rain", value: String(format: "%.1f %@", totalRain, rainUnit), tint: .primary)
            }

            if totalSnow > 0 {
                metric(label: "Snow", value: String(format: "%.1f %@", totalSnow, unitSystem == "imperial" ? "in" : "cm"), tint: .primary)
            }
        }
    }

    private func metric(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
        }
    }

    // MARK: - Helpers

    private func shortPeriodLabel(_ timeLocal: String) -> String {
        let full = formatHour(timeLocal)
        switch full {
        case "Overnight": return "OVNT"
        case "Morning":   return "MORN"
        case "Afternoon":  return "AFTN"
        case "Evening":   return "EVE"
        case "Night":     return "NGHT"
        default:          return full
        }
    }
}
