import SwiftUI

// MARK: - Reusable Card Container

struct InfoCardContainer<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            .foregroundStyle(.secondary)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .carrotCard(padding: 14)
    }
}

// MARK: - Sunrise & Sunset

struct SunriseSunsetCard: View {
    let data: SunriseSunset

    var body: some View {
        InfoCardContainer(title: "Sun", systemImage: "sunrise.fill") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(.orange)
                    Text(formatTime(data.sunrise))
                        .font(.callout.weight(.semibold))
                    Text("Rise").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Image(systemName: "sunset.fill")
                        .foregroundStyle(.orange)
                    Text(formatTime(data.sunset))
                        .font(.callout.weight(.semibold))
                    Text("Set").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - UV Index

struct UVIndexCard: View {
    let data: UVIndex

    var body: some View {
        InfoCardContainer(title: "UV Index", systemImage: "sun.max.fill") {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(data.index)")
                    .font(.title.weight(.semibold))
                Text(data.level)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                        Capsule()
                            .fill(uvColor(for: data.index))
                            .frame(width: geo.size.width * min(Double(data.index) / 11.0, 1.0))
                    }
                }
                .frame(height: 5)
            }
        }
    }
}

// MARK: - Air Quality

struct AirQualityCard: View {
    let data: AirQuality

    var body: some View {
        InfoCardContainer(title: "Air Quality", systemImage: "aqi.medium") {
            if let index = data.index {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(index)")
                        .font(.title.weight(.semibold))
                    if let category = data.category {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Yesterday

struct YesterdayCard: View {
    let data: [HistoricalTemperature]

    var body: some View {
        InfoCardContainer(title: "Yesterday", systemImage: "calendar.badge.clock") {
            if let entry = data.first {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if let high = entry.high {
                            Text("\(Int(high.rounded()))°")
                                .font(.title.weight(.semibold))
                        }
                        if entry.high != nil && entry.low != nil {
                            Text("/")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        if let low = entry.low {
                            Text("\(Int(low.rounded()))°")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("High / Low")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Wind

struct WindCard: View {
    let wind: Wind
    @AppStorage("unitSystem") private var unitSystem: String = "metric"

    private var speedUnit: String { unitSystem == "imperial" ? "mph" : "km/h" }

    var body: some View {
        InfoCardContainer(title: "Wind", systemImage: "wind") {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(wind.speed.rounded()))")
                        .font(.title.weight(.semibold))
                    Text(speedUnit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up")
                        .rotationEffect(.degrees(windDirectionDegrees(wind.direction)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CarrotStyle.accent)
                    Text(wind.direction)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let gust = wind.gust {
                    Text("Gusts \(Int(gust.rounded())) \(speedUnit)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Feels Like

struct FeelsLikeCard: View {
    let feelsLike: Double
    let actual: Double

    var body: some View {
        InfoCardContainer(title: "Feels Like", systemImage: "thermometer.medium") {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(feelsLike.rounded()))°")
                    .font(.title.weight(.semibold))
                let diff = feelsLike - actual
                if abs(diff) >= 1 {
                    Text(diff < 0 ? "Wind makes it feel colder" : "Humidity makes it feel warmer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Close to actual")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Humidity

struct HumidityCard: View {
    let humidity: Double
    let dewPoint: Double

    var body: some View {
        InfoCardContainer(title: "Humidity", systemImage: "humidity.fill") {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(humidity.rounded()))%")
                    .font(.title.weight(.semibold))
                Text("Dew point \(Int(dewPoint.rounded()))°")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Pressure

struct PressureCard: View {
    let pressure: Double

    var body: some View {
        InfoCardContainer(title: "Pressure", systemImage: "gauge.medium") {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", pressure))
                    .font(.title.weight(.semibold))
                Text("kPa")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Visibility

struct VisibilityCard: View {
    let visibility: Double
    @AppStorage("unitSystem") private var unitSystem: String = "metric"

    private var distanceUnit: String { unitSystem == "imperial" ? "mi" : "km" }
    private var goodThreshold: Double { unitSystem == "imperial" ? 6 : 10 }
    private var clearThreshold: Double { unitSystem == "imperial" ? 12 : 20 }

    var body: some View {
        InfoCardContainer(title: "Visibility", systemImage: "eye.fill") {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(visibility.rounded()))")
                        .font(.title.weight(.semibold))
                    Text(distanceUnit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(visibility >= clearThreshold ? "Perfectly clear"
                     : visibility >= goodThreshold ? "Good"
                     : "Limited")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Pollen

struct PollenCard: View {
    let data: PollenObservation

    var body: some View {
        InfoCardContainer(title: "Pollen", systemImage: "leaf.fill") {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(data.index)")
                    .font(.title.weight(.semibold))
                Text(data.level)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule()
                            .fill(pollenColor(for: data.index))
                            .frame(width: geo.size.width * min(Double(data.index) / 5.0, 1.0))
                    }
                }
                .frame(height: 5)
            }
        }
    }

    private func pollenColor(for index: Int) -> Color {
        switch index {
        case 0: .green
        case 1: .yellow
        case 2: .orange
        case 3: .red
        default: .purple
        }
    }
}

// MARK: - Health Indices

struct HealthCard: View {
    let indices: [HealthIndex]

    var body: some View {
        InfoCardContainer(title: "Health", systemImage: "heart.fill") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(indices.prefix(3)) { index in
                    HStack {
                        Text(index.name)
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text(index.risk)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(healthRiskColor(index.value))
                    }
                }
            }
        }
    }

    private func healthRiskColor(_ value: Int) -> Color {
        switch value {
        case 75...: .red
        case 50...: .orange
        case 25...: .yellow
        default: .secondary
        }
    }
}

// MARK: - Monthly Average

struct MonthlyAverageCard: View {
    let data: MonthlyAverage
    var dailyAverages: [DailyAverage] = []

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CarrotSectionHeader("\(monthName) Averages", systemImage: "chart.bar.fill")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(data.avgHigh.rounded()))°")
                    .font(.title.weight(.semibold))
                Text("/")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text("\(Int(data.avgLow.rounded()))°")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text("Avg High / Low")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !dailyAverages.isEmpty {
                dailyTemperatureChart
                    .frame(height: 60)
                    .padding(.top, 4)
            }

            Text("Avg humidity \(Int(data.avgHumidity.rounded()))%")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .carrotCard()
    }

    private var dailyTemperatureChart: some View {
        GeometryReader { geo in
            let days = dailyAverages
            let allTemps = days.flatMap { [$0.high, $0.low] }
            let minTemp = allTemps.min() ?? 0
            let maxTemp = allTemps.max() ?? 1
            let range = max(maxTemp - minTemp, 1)
            let barWidth = max(2, (geo.size.width - CGFloat(days.count - 1)) / CGFloat(days.count))
            let spacing: CGFloat = 1

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(days) { day in
                    let lowFrac = CGFloat((day.low - minTemp) / range)
                    let highFrac = CGFloat((day.high - minTemp) / range)
                    let barBottom = lowFrac * geo.size.height
                    let barTop = highFrac * geo.size.height
                    let barHeight = max(2, barTop - barBottom)

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        temperatureColor(forCelsius: day.high),
                                        temperatureColor(forCelsius: day.low),
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: barWidth, height: barHeight)
                            .padding(.bottom, barBottom)
                    }
                }
            }
        }
    }
}
