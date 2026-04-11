import SwiftUI

struct HourlyForecastView: View {
    let periods: [HourlyPeriod]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Short-Term Forecast", systemImage: "clock")
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                        if index > 0 && isDifferentDay(periods[index - 1].timeLocal, period.timeLocal) {
                            dayDivider(for: period.timeLocal)
                        }
                        hourlyCard(period)
                            .padding(.horizontal, 7)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func dayDivider(for timeLocal: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(width: 1)
            Text(formatDayShort(timeLocal))
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .fixedSize()
            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(width: 1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
    }

    private func hourlyCard(_ period: HourlyPeriod) -> some View {
        VStack(spacing: 8) {
            Text(formatHour(period.timeLocal))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Image(systemName: weatherSymbol(for: period.weather.icon))
                .font(.title2)
                .symbolRenderingMode(.multicolor)

            Text("\(Int(period.temperature.rounded()))°")
                .font(.title3.weight(.medium))

            if period.pop > 0 {
                Text("\(period.pop)%")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.cyan)
            }

            Text("\(period.wind.direction) \(Int(period.wind.speed))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 72)
        .padding(.vertical, 12)
    }
}
