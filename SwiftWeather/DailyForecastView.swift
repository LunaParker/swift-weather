import SwiftUI

enum DailyMetric: String, CaseIterable, Identifiable {
    case temp = "Temp"
    case feelsLike = "Feels Like"
    case precip = "Precip Chance"
    var id: String { rawValue }
}

struct DailyForecastView: View {
    let days: [DailyForecast]
    @State private var metric: DailyMetric = .temp

    private var range: (min: Double, max: Double) {
        var lo = Double.infinity
        var hi = -Double.infinity
        for d in days {
            let pair = values(for: d)
            lo = Swift.min(lo, pair.low)
            hi = Swift.max(hi, pair.high)
        }
        if !lo.isFinite { lo = 0 }
        if !hi.isFinite { hi = 1 }
        if hi - lo < 0.5 { hi = lo + 1 }
        return (lo, hi)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CarrotSectionHeader("Daily Forecast", systemImage: "calendar")
                Spacer()
            }

            metricPicker

            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                dailyRow(day)
                if index < days.count - 1 {
                    Divider().opacity(0.35)
                }
            }
        }
        .carrotCard()
    }

    // MARK: - Metric picker (Carrot-style segmented capsule pills)

    private var metricPicker: some View {
        HStack(spacing: 8) {
            ForEach(DailyMetric.allCases) { m in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        metric = m
                    }
                } label: {
                    Text(m.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .foregroundStyle(metric == m ? Color.white : CarrotStyle.accent)
                        .background(
                            Capsule().fill(metric == m ? CarrotStyle.accent : CarrotStyle.accentSoft)
                        )
                        .overlay(
                            Capsule().stroke(metric == m ? Color.clear : CarrotStyle.accent.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Row

    private func dailyRow(_ day: DailyForecast) -> some View {
        let values = self.values(for: day)
        let r = range

        return HStack(spacing: 12) {
            // Day name + numeric date
            VStack(alignment: .leading, spacing: 0) {
                Text(dayLabel(day.dateLocal).primary)
                    .font(.body.weight(.semibold))
                Text(dayLabel(day.dateLocal).secondary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 78, alignment: .leading)

            // Weather icon
            WeatherSymbol(icon: day.day.weather.icon)
                .font(.title3)
                .frame(width: 28)

            // Precip %
            Group {
                if day.day.pop > 0 {
                    Text("\(day.day.pop)%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CarrotStyle.precipBlue)
                } else {
                    Text("")
                }
            }
            .frame(width: 36, alignment: .leading)

            Spacer(minLength: 4)

            // Low — range bar — high
            metricBar(low: values.low, high: values.high, range: r)
                .frame(maxWidth: 170)
        }
        .padding(.vertical, 8)
    }

    private func metricBar(low: Double, high: Double, range: (min: Double, max: Double)) -> some View {
        let format: (Double) -> String = { v in
            metric == .precip ? "\(Int(v.rounded()))%" : "\(Int(v.rounded()))°"
        }

        return HStack(spacing: 8) {
            Text(format(low))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)

            GeometryReader { geo in
                let span = max(range.max - range.min, 1)
                let leftPct = max(0, min(1, (low - range.min) / span))
                let widthPct = max(0.04, min(1 - leftPct, (high - low) / span))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))

                    Capsule()
                        .fill(barGradient(low: low, high: high))
                        .frame(width: max(geo.size.width * widthPct, 6))
                        .offset(x: geo.size.width * leftPct)
                }
            }
            .frame(height: 6)

            Text(format(high))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, alignment: .leading)
        }
    }

    private func barGradient(low: Double, high: Double) -> LinearGradient {
        switch metric {
        case .precip:
            return LinearGradient(
                colors: [
                    CarrotStyle.precipBlue.opacity(0.5),
                    CarrotStyle.precipBlue,
                ],
                startPoint: .leading, endPoint: .trailing
            )
        case .temp, .feelsLike:
            return LinearGradient(
                colors: [
                    temperatureColor(forCelsius: low),
                    temperatureColor(forCelsius: high),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    // MARK: - Metric extraction

    private func values(for day: DailyForecast) -> (low: Double, high: Double) {
        switch metric {
        case .temp:
            return (day.night.temperature, day.day.temperature)
        case .feelsLike:
            return (day.night.feelsLike, day.day.feelsLike)
        case .precip:
            return (Double(day.night.pop), Double(day.day.pop))
        }
    }

    // MARK: - Date labels

    private func dayLabel(_ isoString: String) -> (primary: String, secondary: String) {
        let primary = formatDay(isoString) // "Today" / "Tomorrow" / "Mon, May 18"
        // For the dense Carrot layout we split into the first token + the rest.
        if primary == "Today" || primary == "Tomorrow" {
            return (primary, "")
        }
        let parts = primary.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2 {
            return (parts[0], parts[1])
        }
        return (primary, "")
    }
}
