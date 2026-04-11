import SwiftUI

// MARK: - Sunrise & Sunset

struct SunriseSunsetCard: View {
    let data: SunriseSunset

    var body: some View {
        InfoCardContainer(title: "Sunrise & Sunset", systemImage: "sunrise.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text(formatTime(data.sunrise))
                            .font(.title2.weight(.light))
                        Text("Sunrise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Image(systemName: "sunset.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text(formatTime(data.sunset))
                            .font(.title2.weight(.light))
                        Text("Sunset")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            VStack(alignment: .leading, spacing: 8) {
                Text("\(data.index)")
                    .font(.title.weight(.light))
                Text(data.level)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index)")
                        .font(.title.weight(.light))
                    if let category = data.category {
                        Text(category)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    if let source = data.source {
                        Text("Source: \(source)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                }
            } else {
                Text("No data available")
                    .font(.callout)
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if let high = entry.high {
                            Text("\(Int(high.rounded()))°")
                                .font(.title.weight(.light))
                        }
                        if entry.high != nil && entry.low != nil {
                            Text("/")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        if let low = entry.low {
                            Text("\(Int(low.rounded()))°")
                                .font(.title2.weight(.light))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("High / Low")
                        .font(.caption)
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(wind.speed.rounded()))")
                        .font(.title.weight(.light))
                    Text(speedUnit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "arrow.up")
                        .rotationEffect(.degrees(windDirectionDegrees(wind.direction)))
                        .font(.body)
                    Text(wind.direction)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let gust = wind.gust {
                    HStack(spacing: 4) {
                        Text("Gusts:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(gust.rounded())) \(speedUnit)")
                            .font(.caption.weight(.medium))
                    }
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
                    .font(.title.weight(.light))
                let diff = feelsLike - actual
                if abs(diff) >= 1 {
                    Text(diff < 0 ? "Wind is making it feel colder" : "Humidity is making it feel warmer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Similar to the actual temperature")
                        .font(.caption)
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
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(humidity.rounded()))%")
                    .font(.title.weight(.light))
                Text("The dew point is \(Int(dewPoint.rounded()))° right now")
                    .font(.caption)
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
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", pressure))
                        .font(.title.weight(.light))
                    Text("kPa")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(visibility.rounded()))")
                        .font(.title.weight(.light))
                    Text(distanceUnit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if visibility >= clearThreshold {
                    Text("It's perfectly clear right now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if visibility >= goodThreshold {
                    Text("Good visibility")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Limited visibility")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Pollen

struct PollenCard: View {
    let data: PollenObservation

    var body: some View {
        InfoCardContainer(title: "Pollen", systemImage: "leaf.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(data.index)")
                    .font(.title.weight(.light))
                Text(data.level)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)
                        Capsule()
                            .fill(pollenColor(for: data.index))
                            .frame(width: geo.size.width * min(Double(data.index) / 5.0, 1.0))
                    }
                }
                .frame(height: 5)

                if !data.species.isEmpty {
                    Text(data.species.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
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
            VStack(alignment: .leading, spacing: 6) {
                ForEach(indices.prefix(3)) { index in
                    HStack {
                        Text(index.name)
                            .font(.callout)
                        Spacer()
                        Text(index.risk)
                            .font(.callout.weight(.medium))
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
            Label("\(monthName) Averages", systemImage: "chart.bar.fill")
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(data.avgHigh.rounded()))°")
                    .font(.title.weight(.light))
                Text("/")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text("\(Int(data.avgLow.rounded()))°")
                    .font(.title2.weight(.light))
                    .foregroundStyle(.secondary)
            }
            Text("Avg High / Low")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !dailyAverages.isEmpty {
                dailyTemperatureChart
                    .frame(height: 60)
                    .padding(.top, 4)
            }

            Text("Humidity: \(Int(data.avgHumidity.rounded()))%")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassEffect(in: .rect(cornerRadius: 16))
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
                                    colors: [.orange.opacity(0.8), .blue.opacity(0.5)],
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

// MARK: - Reusable Card Container

struct InfoCardContainer<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}
