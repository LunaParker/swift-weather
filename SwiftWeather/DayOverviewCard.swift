import SwiftUI
import FoundationModels

struct DayOverviewCard: View {
    let hourly: [HourlyPeriod]
    let daily: [DailyForecast]

    @State private var aiSummary: String?
    @State private var isGenerating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Today's Overview", systemImage: aiSummary != nil ? "apple.intelligence" : "doc.text")
                    .font(.caption.weight(.medium))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let summary = aiSummary {
                Text(summary)
                    .font(.callout)
                    .transition(.opacity.combined(with: .blurReplace))
            } else if isGenerating {
                HStack(spacing: 8) {
                    Text("Generating summary…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else {
                Text(fallbackText)
                    .font(.callout)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: aiSummary != nil)
        .animation(.easeInOut(duration: 0.3), value: isGenerating)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
        .task(id: weatherDataID) {
            await generateAISummary()
        }
    }

    /// Periods remaining in today, from now onward.
    private var remainingPeriods: [HourlyPeriod] {
        todayPeriodsAfterNow(hourly)
    }

    /// Stable ID so `.task` re-fires only when weather data actually changes.
    /// Keyed on the remaining-periods set so the summary regenerates as the
    /// day advances and periods drop off.
    private var weatherDataID: String {
        let remaining = remainingPeriods
        let temps = remaining.map { "\($0.timeLocal):\(Int(self.roundTemp($0.temperature)))" }.joined(separator: ",")
        let day = daily.first.map { "\(Int(roundTemp($0.day.temperature)))/\(Int(roundTemp($0.night.temperature)))" } ?? ""
        return "\(temps)|\(day)"
    }

    private func roundTemp(_ t: Double) -> Double { t.rounded() }

    // MARK: - Apple Intelligence Summary

    private func generateAISummary() async {
        guard SystemLanguageModel.default.availability == .available else { return }

        // If there are no periods left in today, skip the AI summary and
        // let the fallback template handle the end-of-day state.
        let remaining = remainingPeriods
        guard !remaining.isEmpty else { return }

        isGenerating = true
        defer { isGenerating = false }

        let prompt = buildPrompt(remaining: remaining)

        do {
            let session = LanguageModelSession {
                """
                STRICT RULES — you must follow ALL of these:
                1. Write 2-3 short sentences summarizing the rest of today. No more than 3 sentences.
                2. NEVER use bullet points, asterisks, lists, line breaks, or Markdown of any kind.
                3. Do NOT describe each time period individually — give one cohesive summary.
                4. Be natural and conversational. Do not say "today's weather" or "here is".
                5. Use PRESENT or FUTURE tense only. The day is still in progress — never describe it as finished or in the past. Do not say "was", "started", "came to a close", "ended", or similar. Use "is", "will be", "expect", "brings", etc.
                6. Only describe the periods provided — they represent what is still ahead today. Do not describe periods that have already passed.
                7. Mention the high/low temperatures, general conditions, and precipitation only if significant.
                """
            }
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                withAnimation(.easeIn(duration: 0.4)) {
                    aiSummary = text
                }
            }
        } catch {
            // Silently fall back to template text
        }
    }

    private func buildPrompt(remaining: [HourlyPeriod]) -> String {
        let today = daily.first
        let highTemp = today?.day.temperature ?? today?.maxTemperature
        let lowTemp = today?.night.temperature ?? today?.minTemperature

        var lines: [String] = []
        lines.append("Summarize the rest of today's weather forecast from this data. The day is still in progress — describe only what is still ahead, in present or future tense.")

        if let hi = highTemp { lines.append("Today's high: \(Int(hi.rounded()))°") }
        if let lo = lowTemp { lines.append("Today's low: \(Int(lo.rounded()))°") }
        if let today { lines.append("Day POP: \(today.day.pop)%, Night POP: \(today.night.pop)%") }
        if let today { lines.append("Day condition: \(today.day.weather.text), Night condition: \(today.night.weather.text)") }

        lines.append("Remaining periods today (describe these only):")
        for period in remaining {
            lines.append("• \(formatHour(period.timeLocal)): \(period.weather.text), \(Int(period.temperature.rounded()))°, POP \(period.pop)%, Wind \(period.wind.direction) \(Int(period.wind.speed))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Fallback (template-based)

    private var fallbackText: String {
        let today = daily.first
        let remaining = remainingPeriods

        // If nothing left in today, close out with a brief night summary.
        guard !remaining.isEmpty else {
            guard let today else { return "Weather data is loading." }
            let nightCondition = today.night.weather.text
            let lowTemp = today.night.temperature
            if !nightCondition.isEmpty {
                return "\(nightCondition) overnight with a low of \(Int(lowTemp.rounded()))°."
            }
            return "Low of \(Int(lowTemp.rounded()))° overnight."
        }

        var parts: [String] = []

        // Lead with the next upcoming period's condition for a present-tense hook.
        if let next = remaining.first {
            let label = formatHour(next.timeLocal).lowercased()
            let condition = next.weather.text
            if !condition.isEmpty {
                parts.append("\(condition) this \(label)")
            }
        }

        // Add a precipitation callout if anything remaining is notable.
        if let maxPop = remaining.map(\.pop).max(), maxPop >= 30 {
            parts.append("\(maxPop)% chance of precipitation")
        }

        // Temperature context — use today's high only if it's still ahead,
        // otherwise just cite the low we're heading toward.
        if let today {
            let highTemp = today.day.temperature
            let lowTemp = today.night.temperature
            let highStillAhead = remaining.contains { $0.temperature >= highTemp - 0.5 }
            if highStillAhead {
                parts.append("High of \(Int(highTemp.rounded()))° and low of \(Int(lowTemp.rounded()))°")
            } else {
                parts.append("Heading to a low of \(Int(lowTemp.rounded()))°")
            }
        }

        if parts.isEmpty { return "Weather data is loading." }
        return parts.joined(separator: ". ") + "."
    }
}
