import SwiftUI

struct HourlyForecastView: View {
    let periods: [HourlyPeriod]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CarrotSectionHeader("Hourly Forecast", systemImage: "clock")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 18) {
                    ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                        if index > 0 && isDifferentDay(periods[index - 1].timeLocal, period.timeLocal) {
                            dayDivider(for: period.timeLocal)
                        }
                        hourlyColumn(period)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .carrotCard()
    }

    private func dayDivider(for timeLocal: String) -> some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            Text(formatDayShort(timeLocal))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private func hourlyColumn(_ period: HourlyPeriod) -> some View {
        VStack(spacing: 6) {
            Text(formatHour(period.timeLocal))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Image(systemName: weatherSymbol(for: period.weather.icon))
                .symbolRenderingMode(.multicolor)
                .font(.title3)
                .frame(height: 22)

            Text("\(Int(period.temperature.rounded()))°")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(period.pop > 0 ? "\(period.pop)%" : "—")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(period.pop > 0 ? CarrotStyle.precipBlue : .clear)
                .frame(height: 12)
        }
        .frame(width: 44)
    }
}
