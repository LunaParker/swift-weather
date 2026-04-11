import Foundation

// MARK: - Location

struct Location: Identifiable, Hashable, Sendable {
    let code: String
    let name: String
    let province: String
    let country: String
    let latitude: Double
    let longitude: Double
    let timezone: String

    var id: String { code }
    var subtitle: String {
        [province, country].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

extension Location: Codable {
    private struct NameEntry: Decodable {
        let name: String
        let provName: String?
        let countryName: String?
    }

    private enum CodingKeys: String, CodingKey {
        case code, name, latitude, longitude
        case provName, countryName
        case timeZoneOlson
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        timezone = (try? c.decode(String.self, forKey: .timeZoneOlson)) ?? ""

        if let entries = try? c.decode([NameEntry].self, forKey: .name),
           let first = entries.first {
            name = first.name
            province = first.provName ?? ""
            country = first.countryName ?? ""
        } else {
            name = (try? c.decode(String.self, forKey: .name)) ?? ""
            province = (try? c.decode(String.self, forKey: .provName)) ?? ""
            country = (try? c.decode(String.self, forKey: .countryName)) ?? ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(code, forKey: .code)
        try c.encode(name, forKey: .name)
        try c.encode(province, forKey: .provName)
        try c.encode(country, forKey: .countryName)
        try c.encode(latitude, forKey: .latitude)
        try c.encode(longitude, forKey: .longitude)
        try c.encode(timezone, forKey: .timeZoneOlson)
    }
}

// MARK: - Recent Location Weather Snapshot

struct RecentLocationWeather: Identifiable {
    let location: Location
    var current: CurrentWeather?
    var highTemp: Double?
    var lowTemp: Double?
    var isLoading: Bool = true
    var id: String { location.id }
}

// MARK: - Shared Components

struct Wind: Decodable, Sendable {
    let direction: String
    let speed: Double
    let gust: Double?

    init(direction: String = "N", speed: Double = 0, gust: Double? = nil) {
        self.direction = direction
        self.speed = speed
        self.gust = gust
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        direction = (try? c.decode(String.self, forKey: .direction)) ?? "N"
        speed = (try? c.decode(Double.self, forKey: .speed)) ?? 0
        gust = try? c.decode(Double.self, forKey: .gust)
    }

    private enum CodingKeys: String, CodingKey { case direction, speed, gust }
}

struct Precipitation: Decodable, Sendable {
    let value: Double
    let range: String

    init(value: Double = 0, range: String = "0") {
        self.value = value
        self.range = range
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = (try? c.decode(Double.self, forKey: .value)) ?? 0
        range = (try? c.decode(String.self, forKey: .range)) ?? "0"
    }

    private enum CodingKeys: String, CodingKey { case value, range }
}

struct WeatherCode: Decodable, Sendable {
    let code: String
    let icon: Int
    let text: String

    private enum CodingKeys: String, CodingKey {
        case code = "value"
        case icon, text
    }

    init(code: String = "", icon: Int = 0, text: String = "") {
        self.code = code
        self.icon = icon
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decode(String.self, forKey: .code)) ?? ""
        icon = (try? c.decode(Int.self, forKey: .icon)) ?? 0
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
    }
}

// MARK: - Current Observation

struct CurrentWeather: Sendable {
    let timeLocal: String
    let weather: WeatherCode
    let temperature: Double
    let dewPoint: Double
    let feelsLike: Double
    let wind: Wind
    let humidity: Double
    let pressure: Double
    let visibility: Double
    let ceiling: Double?
}

// MARK: - Short Term (Hourly)

struct HourlyPeriod: Identifiable, Sendable {
    let id: Int
    let timeLocal: String
    let weather: WeatherCode
    let temperature: Double
    let feelsLike: Double
    let wind: Wind
    let pop: Int
    let humidity: Double
    let rain: Precipitation
    let snow: Precipitation
}

// MARK: - Long Term (Daily)

struct DayNightForecast: Sendable {
    let weather: WeatherCode
    let temperature: Double
    let feelsLike: Double
    let wind: Wind
    let pop: Int
    let humidity: Double
    let rain: Precipitation
    let snow: Precipitation
}

struct DailyForecast: Identifiable, Sendable {
    let id: String
    let dateLocal: String
    let maxTemperature: Double?
    let minTemperature: Double?
    let totalRain: Precipitation
    let totalSnow: Precipitation
    let hoursOfSun: Int?
    let day: DayNightForecast
    let night: DayNightForecast
}

// MARK: - Astronomy

struct SunriseSunset: Sendable {
    let sunrise: String
    let sunset: String
}

// MARK: - UV Index

struct UVIndex: Sendable {
    let index: Int
    let level: String
    let source: String
}

// MARK: - Air Quality

struct AirQuality: Sendable {
    let index: Int?
    let category: String?
    let pollutant: String?
    let source: String?
}

// MARK: - Historical

struct HistoricalTemperature: Identifiable, Sendable {
    let id: String
    let date: String
    let high: Double?
    let low: Double?
}

// MARK: - Pollen

struct PollenObservation: Sendable {
    let index: Int
    let level: String
    let source: String
    let species: [String]
}

// MARK: - Health Indices

struct HealthIndex: Identifiable, Sendable {
    let id: String
    let name: String
    let risk: String
    let value: Int
}

// MARK: - Monthly Averages

struct MonthlyAverage: Sendable {
    let avgHigh: Double
    let avgLow: Double
    let avgHumidity: Double
    let totalRain: Double
    let totalSnow: Double
}

// MARK: - Weather Alerts

struct WeatherAlert: Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let severity: String
    let issuedTime: String
    let expiryTime: String
}

// MARK: - Daily Climate Average

struct DailyAverage: Identifiable, Sendable {
    let id: String
    let date: String
    let high: Double
    let low: Double
    let precipFrequency: Int
}

// MARK: - Combined Weather Data

struct AllWeatherData: Sendable {
    let current: CurrentWeather
    let hourly: [HourlyPeriod]
    let daily: [DailyForecast]
    let sun: SunriseSunset
    let uv: UVIndex
    let airQuality: AirQuality?
    let yesterday: [HistoricalTemperature]
    let pollen: PollenObservation?
    let healthIndices: [HealthIndex]
    let monthlyAverage: MonthlyAverage?
    let alerts: [WeatherAlert]
    let dailyAverages: [DailyAverage]
}

// MARK: - API Response Wrappers

enum APIResponse {
    struct Search: Decodable {
        let profile: [ProfileEntry]?
        struct ProfileEntry: Decodable {
            let location: [Location]?
        }
    }

    struct TimeData: Decodable {
        let local: String
        let utc: String?
    }

    struct TempWrapper: Decodable {
        let value: Double

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            value = (try? c.decode(Double.self, forKey: .value)) ?? 0
        }

        private enum CodingKeys: String, CodingKey { case value }
    }

    struct PressureWrapper: Decodable {
        let value: Double
    }

    struct Observation: Decodable {
        let observation: ObsData
        struct ObsData: Decodable {
            let time: TimeData
            let weatherCode: WeatherCode
            let temperature: Double
            let dewPoint: Double
            let feelsLike: Double
            let wind: Wind
            let relativeHumidity: Double
            let pressure: PressureWrapper
            let visibility: Double
            let ceiling: Double?
        }
    }

    struct ShortTerm: Decodable {
        let shortTerm: [Period]
        struct Period: Decodable {
            let period: Int
            let time: TimeData
            let weatherCode: WeatherCode
            let temperature: TempWrapper
            let feelsLike: Double
            let wind: Wind
            let pop: Int?
            let relativeHumidity: Double?
            let rain: Precipitation?
            let snow: Precipitation?
            let dewPoint: Double?
            let pressure: Double?
            let cloudCover: Int?
        }
    }

    struct LongTerm: Decodable {
        let longTerm: [Day]
        struct Day: Decodable {
            let time: TimeData
            let maxTemperature: Double?
            let minTemperature: Double?
            let rain: Precipitation?
            let snow: Precipitation?
            let hoursOfSun: Int?
            let day: DayNight
            let night: DayNight
            let dayType: String?
        }
        struct DayNight: Decodable {
            let weatherCode: WeatherCode
            let temperature: TempWrapper
            let feelsLike: Double
            let wind: Wind
            let pop: Int?
            let relativeHumidity: Double?
            let rain: Precipitation?
            let snow: Precipitation?
            let cloudCover: Int?
        }
    }

    struct Astronomy: Decodable {
        let times: [TimeEntry]
        struct TimeEntry: Decodable {
            let sunrise: String
            let sunset: String
        }
    }

    struct UV: Decodable {
        let uvObservation: UVObs
        let source: TextWrapper?
        struct UVObs: Decodable {
            let time: TimeData
            let index: IndexWrapper
        }
        struct IndexWrapper: Decodable {
            let value: Int
            let text: String
        }
    }

    struct AirQualityObs: Decodable {
        let airQualityObservation: AQObs
        struct AQObs: Decodable {
            let index: IndexWrapper
            let pollutionCode: TextWrapper?
            let source: TextWrapper?
        }
        struct IndexWrapper: Decodable {
            let value: Int?
            let text: String?
        }
    }

    struct TextWrapper: Decodable {
        let text: String?
    }

    struct Historical: Decodable {
        let history: [Entry]?
        struct Entry: Decodable {
            let timestamp: String
            let temperature: TempRange
        }
        struct TempRange: Decodable {
            let maximum: Double?
            let minimum: Double?
        }
    }

    struct PollenResponse: Decodable {
        let source: TextWrapper?
        let pollenObservation: PollenObs
        struct PollenObs: Decodable {
            let index: IndexWrapper
            let species: [Species]?
        }
        struct IndexWrapper: Decodable {
            let value: Int
            let text: String
        }
        struct Species: Decodable {
            let name: String
        }
    }

    struct HealthIndicesResponse: Decodable {
        let categories: [String: [HealthEntry]]

        struct HealthEntry: Decodable {
            let value: Int
            let risk: String
            let risk_label: String
            let period: Int
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicKey.self)
            var cats: [String: [HealthEntry]] = [:]
            for key in container.allKeys {
                if let entries = try? container.decode([HealthEntry].self, forKey: key) {
                    cats[key.stringValue] = entries
                }
            }
            categories = cats
        }

        private struct DynamicKey: CodingKey {
            var stringValue: String
            init?(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue: Int) { nil }
        }
    }

    struct AveragesResponse: Decodable {
        let days: [DayAvg]?
        struct DayAvg: Decodable {
            let timestamp: String?
            let temperatureMax: Double?
            let temperatureMin: Double?
            let relativeHumidity: Double?
            let rain: Precipitation?
            let snow: Precipitation?
            let precipitationFrequency: Int?
        }
    }

    struct AlertResponse: Decodable {
        let alerts: [AlertEntry]

        struct AlertEntry: Decodable {
            let alertId: String?
            let headline: String?
            let description: String?
            let severity: String?
            let issued: TimeData?
            let expires: TimeData?
            let event: String?
            let areaDescription: String?

            private enum CodingKeys: String, CodingKey {
                case alertId, headline, description, severity
                case issued, expires, event, areaDescription
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                alertId = try? c.decode(String.self, forKey: .alertId)
                headline = try? c.decode(String.self, forKey: .headline)
                description = try? c.decode(String.self, forKey: .description)
                severity = try? c.decode(String.self, forKey: .severity)
                issued = try? c.decode(TimeData.self, forKey: .issued)
                expires = try? c.decode(TimeData.self, forKey: .expires)
                event = try? c.decode(String.self, forKey: .event)
                areaDescription = try? c.decode(String.self, forKey: .areaDescription)
            }
        }
    }

}
