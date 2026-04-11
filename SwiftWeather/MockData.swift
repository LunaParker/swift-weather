import Foundation

enum MockData {
    static let torontoLocation = Location(
        code: "CAON0696",
        name: "Toronto",
        province: "Ontario",
        country: "Canada",
        latitude: 43.667,
        longitude: -79.407,
        timezone: "America/Toronto"
    )

    static func searchResults(for query: String) -> [Location] {
        let q = query.lowercased()
        if "toronto".contains(q) || q.contains("tor") {
            return [torontoLocation]
        }
        return []
    }

    static func allWeather() -> AllWeatherData {
        let now = Date()
        let cal = Calendar.current
        let isoLocal = { (date: Date) -> String in
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm"
            return f.string(from: date)
        }
        let isoFull = { (date: Date) -> String in
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.string(from: date)
        }

        let current = CurrentWeather(
            timeLocal: isoLocal(now),
            weather: WeatherCode(code: "S+", icon: 2, text: "Mainly sunny"),
            temperature: 14,
            dewPoint: 5,
            feelsLike: 11,
            wind: Wind(direction: "SW", speed: 22, gust: 35),
            humidity: 52,
            pressure: 101.8,
            visibility: 24,
            ceiling: 7600
        )

        // 24 six-hour periods covering 6 days (matches API's shortterm format with count=24)
        let hourlyWeathers: [(Int, String, Double, Int)] = [
            (2, "Mainly sunny", 16, 10),
            (3, "Partly cloudy", 17, 20),
            (6, "Chance of a shower", 14, 60),
            (18, "Clear", 8, 10),
            (19, "Partly cloudy", 6, 10),
            (2, "Mainly sunny", 10, 10),
            (3, "Partly cloudy", 14, 20),
            (6, "Chance of a shower", 12, 40),
            (2, "Mainly sunny", 15, 10),
            (5, "Cloudy", 13, 30),
            (12, "Light rain", 10, 70),
            (18, "Clear", 5, 10),
            (2, "Mainly sunny", 12, 10),
            (3, "Partly cloudy", 16, 20),
            (6, "A few showers", 11, 50),
            (18, "Clear", 7, 10),
            (1, "Sunny", 18, 0),
            (3, "Partly cloudy", 15, 10),
            (5, "Cloudy", 12, 30),
            (18, "Clear", 6, 10),
            (2, "Mainly sunny", 14, 10),
            (6, "Chance of a shower", 13, 40),
            (12, "Rain", 9, 80),
            (19, "Partly cloudy", 4, 20),
        ]
        // Align to next 6-hour block boundary
        let currentHour = cal.component(.hour, from: now)
        let hoursToNext = (6 - (currentHour % 6)) % 6
        let blockStart = cal.date(byAdding: .hour, value: hoursToNext == 0 ? 6 : hoursToNext, to: now)!
        let hourly = hourlyWeathers.enumerated().map { i, w in
            let time = cal.date(byAdding: .hour, value: i * 6, to: blockStart)!
            return HourlyPeriod(
                id: i,
                timeLocal: isoLocal(time),
                weather: WeatherCode(code: "", icon: w.0, text: w.1),
                temperature: w.2,
                feelsLike: w.2 - 3,
                wind: Wind(direction: "SW", speed: Double.random(in: 12...28)),
                pop: w.3,
                humidity: Double.random(in: 40...70),
                rain: Precipitation(),
                snow: Precipitation()
            )
        }

        let dailyConditions: [(Int, String, Double, Double, Int)] = [
            (2, "Mainly sunny", 16, 5, 20),
            (12, "Rain", 7, 0, 100),
            (1, "Sunny", 10, 0, 10),
            (6, "Cloudy with showers", 8, 6, 40),
            (6, "Chance of a shower", 19, 13, 70),
            (12, "Light rain", 19, 6, 70),
            (12, "Light rain", 9, 3, 70),
            (5, "Cloudy", 8, 3, 40),
            (2, "Mainly sunny", 11, 6, 10),
            (6, "Chance of a shower", 12, 5, 40),
            (6, "A few showers", 11, 5, 60),
            (6, "A few showers", 12, 6, 40),
            (5, "Cloudy", 10, 4, 30),
            (2, "Mainly sunny", 13, 5, 10),
            (5, "Cloudy", 11, 4, 30),
        ]
        let daily = dailyConditions.enumerated().map { i, d in
            let date = cal.date(byAdding: .day, value: i, to: cal.startOfDay(for: now))!
            let dateStr = isoLocal(date)
            return DailyForecast(
                id: dateStr,
                dateLocal: dateStr,
                maxTemperature: d.2,
                minTemperature: d.3,
                totalRain: Precipitation(),
                totalSnow: Precipitation(),
                hoursOfSun: Int.random(in: 2...10),
                day: DayNightForecast(
                    weather: WeatherCode(code: "", icon: d.0, text: d.1),
                    temperature: d.2, feelsLike: d.2 - 3,
                    wind: Wind(direction: "SW", speed: 20),
                    pop: d.4, humidity: 55,
                    rain: Precipitation(), snow: Precipitation()
                ),
                night: DayNightForecast(
                    weather: WeatherCode(code: "", icon: d.0 + 17, text: d.1),
                    temperature: d.3, feelsLike: d.3 - 2,
                    wind: Wind(direction: "NW", speed: 12),
                    pop: max(0, d.4 - 10), humidity: 72,
                    rain: Precipitation(), snow: Precipitation()
                )
            )
        }

        let sunriseTime = cal.date(bySettingHour: 6, minute: 38, second: 0, of: now)!
        let sunsetTime = cal.date(bySettingHour: 19, minute: 55, second: 0, of: now)!
        let sun = SunriseSunset(
            sunrise: isoFull(sunriseTime),
            sunset: isoFull(sunsetTime)
        )

        let uv = UVIndex(index: 4, level: "Moderate", source: "Environment Canada")

        let airQuality = AirQuality(
            index: 3, category: "Low Risk",
            pollutant: nil, source: "Government of Canada"
        )

        let yesterday = [
            HistoricalTemperature(id: "yesterday", date: isoLocal(cal.date(byAdding: .day, value: -1, to: now)!), high: 12, low: 3)
        ]

        let pollen = PollenObservation(index: 3, level: "High", source: "Aerobiology Research Laboratories", species: ["Elm", "Birch"])

        let healthIndices = [
            HealthIndex(id: "migraine", name: "Migraine", risk: "Moderate", value: 50),
            HealthIndex(id: "sinus", name: "Sinus", risk: "Low", value: 25),
        ]

        let monthlyAverage = MonthlyAverage(avgHigh: 12, avgLow: 3, avgHumidity: 62, totalRain: 68.5, totalSnow: 2.1)

        let alerts = [
            WeatherAlert(
                id: "mock-1",
                title: "Special Weather Statement",
                description: "Periods of rain mixed with snow are expected this evening. Accumulations of 2-4 cm are possible in areas north of the city.",
                severity: "Moderate",
                issuedTime: isoLocal(now),
                expiryTime: isoLocal(cal.date(byAdding: .hour, value: 12, to: now)!)
            )
        ]

        let dailyAverages = (1...30).map { day in
            let baseHigh = 8.0 + Double(day) * 0.3
            let baseLow = -1.0 + Double(day) * 0.2
            return DailyAverage(
                id: "\(day)",
                date: isoLocal(cal.date(bySetting: .day, value: day, of: now) ?? now),
                high: baseHigh + Double.random(in: -2...2),
                low: baseLow + Double.random(in: -2...2),
                precipFrequency: Int.random(in: 20...60)
            )
        }

        return AllWeatherData(
            current: current, hourly: hourly, daily: daily,
            sun: sun, uv: uv, airQuality: airQuality, yesterday: yesterday,
            pollen: pollen, healthIndices: healthIndices, monthlyAverage: monthlyAverage,
            alerts: alerts, dailyAverages: dailyAverages
        )
    }
}
