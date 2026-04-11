import SwiftUI
import FoundationModels

struct PrecipitationCard: View {
    let hourly: [HourlyPeriod]
    let daily: [DailyForecast]

    @AppStorage("unitSystem") private var unitSystem: String = "metric"
    @AppStorage("precipThreshold") private var precipThreshold: Int = 40

    @State private var aiSummary: String?
    @State private var isGenerating = false

    private var today: DailyForecast? { daily.first }
    private var todayPeriods: [HourlyPeriod] { Array(hourly.prefix(4)) }
    private var maxPop: Int { todayPeriods.map(\.pop).max() ?? today?.day.pop ?? 0 }
    private var totalRain: Double { today?.totalRain.value ?? 0 }
    private var totalSnow: Double { today?.totalSnow.value ?? 0 }
    private var rainUnit: String { unitSystem == "imperial" ? "in" : "mm" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Precipitation", systemImage: "umbrella.fill")
                    .font(.caption.weight(.medium))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            // Summary text
            if let summary = aiSummary {
                Text(summary)
                    .font(.callout)
                    .transition(.opacity.combined(with: .blurReplace))
            } else if isGenerating {
                Text("Analyzing precipitation…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else {
                Text(fallbackSummary)
                    .font(.callout)
                    .transition(.opacity)
            }

            // Bar chart
            precipitationChart
                .frame(height: 80)

            // Details row
            if maxPop > 0 {
                detailsRow
            }
        }
        .animation(.easeInOut(duration: 0.3), value: aiSummary != nil)
        .animation(.easeInOut(duration: 0.3), value: isGenerating)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
        .task(id: precipDataID) {
            await generateAISummary()
        }
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
            // Strip any Markdown artifacts the model may have included
            text = text.replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "* ", with: "")
                .replacingOccurrences(of: "- ", with: "")
            // If multi-line, keep only the first sentence
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

    // MARK: - Fallback Summary

    private var fallbackSummary: String {
        let threshold = precipThreshold
        if maxPop < threshold {
            return "No precipitation expected today."
        }

        let isCurrentlyRaining = todayPeriods.first.map { $0.pop >= threshold } ?? false

        if isCurrentlyRaining {
            if let stopPeriod = todayPeriods.dropFirst().first(where: { $0.pop < threshold }) {
                return "Precipitation expected to end by \(formatHour(stopPeriod.timeLocal).lowercased())."
            }
            return "Precipitation expected throughout the day."
        } else {
            if let startPeriod = todayPeriods.first(where: { $0.pop >= threshold }) {
                return "Precipitation likely starting \(formatHour(startPeriod.timeLocal).lowercased())."
            }
            return "\(maxPop)% chance of precipitation today."
        }
    }

    // MARK: - Bar Chart

    private var precipitationChart: some View {
        GeometryReader { geo in
            let periods = hourly.prefix(8)
            let barCount = periods.count
            guard barCount > 0 else { return AnyView(EmptyView()) }

            let spacing: CGFloat = 4
            let totalSpacing = spacing * CGFloat(barCount - 1)
            let barWidth = (geo.size.width - totalSpacing) / CGFloat(barCount)

            return AnyView(
                VStack(spacing: 4) {
                    // Bars
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(periods.enumerated()), id: \.element.id) { _, period in
                            precipBar(pop: period.pop, maxHeight: geo.size.height - 20, width: barWidth)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)

                    // Time labels
                    HStack(spacing: spacing) {
                        ForEach(Array(periods.enumerated()), id: \.element.id) { _, period in
                            Text(shortPeriodLabel(period.timeLocal))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: barWidth)
                        }
                    }
                }
            )
        }
    }

    private func precipBar(pop: Int, maxHeight: CGFloat, width: CGFloat) -> some View {
        let fraction = CGFloat(pop) / 100.0
        let minBarHeight: CGFloat = 3
        let barHeight = max(minBarHeight, maxHeight * fraction)

        return RoundedRectangle(cornerRadius: 3)
            .fill(precipBarColor(pop: pop))
            .frame(width: width, height: pop > 0 ? barHeight : minBarHeight)
    }

    private func precipBarColor(pop: Int) -> Color {
        switch pop {
        case 0:     .secondary.opacity(0.15)
        case 1..<30:  .cyan.opacity(0.3)
        case 30..<60: .cyan.opacity(0.55)
        case 60..<80: .cyan.opacity(0.75)
        default:      .cyan
        }
    }

    // MARK: - Details Row

    private var detailsRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Chance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(maxPop)%")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.cyan)
            }

            if totalRain > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rain")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f %@", totalRain, rainUnit))
                        .font(.callout.weight(.medium))
                }
            }

            if totalSnow > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Snow")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f %@", totalSnow, unitSystem == "imperial" ? "in" : "cm"))
                        .font(.callout.weight(.medium))
                }
            }
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
