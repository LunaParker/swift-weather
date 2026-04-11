import SwiftUI

struct DailyForecastView: View {
    let days: [DailyForecast]

    private var tempRange: (min: Double, max: Double, span: Double) {
        var lo = Double.infinity
        var hi = -Double.infinity
        for d in days {
            hi = max(hi, d.day.temperature)
            lo = min(lo, d.night.temperature)
        }
        let span = hi - lo
        return (lo, hi, span > 0 ? span : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("15-Day Forecast", systemImage: "calendar")
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                dailyRow(day)
                if index < days.count - 1 {
                    Divider()
                        .opacity(0.4)
                }
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func dailyRow(_ day: DailyForecast) -> some View {
        HStack(spacing: 0) {
            Text(formatDay(day.dateLocal))
                .font(.body.weight(.medium))
                .frame(width: 110, alignment: .leading)

            Image(systemName: weatherSymbol(for: day.day.weather.icon))
                .symbolRenderingMode(.multicolor)
                .font(.body)
                .frame(width: 32)

            Text(day.day.weather.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)

            if day.day.pop > 0 {
                Text("\(day.day.pop)%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.cyan)
                    .frame(width: 44, alignment: .trailing)
            } else {
                Spacer().frame(width: 44)
            }

            tempBarSection(day)
                .frame(width: 160)
        }
        .padding(.vertical, 10)
    }

    private func tempBarSection(_ day: DailyForecast) -> some View {
        let range = tempRange
        let lo = day.night.temperature
        let hi = day.day.temperature

        return HStack(spacing: 6) {
            Text("\(Int(lo.rounded()))°")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            GeometryReader { geo in
                let width = geo.size.width
                let leftPct = (lo - range.min) / range.span
                let widthPct = (hi - lo) / range.span

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(width * widthPct, 4))
                        .offset(x: width * leftPct)
                }
            }
            .frame(height: 5)

            Text("\(Int(hi.rounded()))°")
                .font(.caption.weight(.medium))
                .frame(width: 28, alignment: .leading)
        }
    }
}
