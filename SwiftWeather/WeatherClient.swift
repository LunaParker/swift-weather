import Foundation

enum WeatherClientError: LocalizedError, Equatable {
    case noData
    case invalidURL
    case rateLimited
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .noData: return "No weather data available"
        case .invalidURL: return "Invalid request URL"
        case .rateLimited: return "Too many requests — the weather API has temporarily blocked this device. Please wait a few minutes and try again."
        case .serverError(let code): return "The weather API returned an error (HTTP \(code)). Please try again later."
        }
    }
}

enum WeatherClient {
    private static let weatherBase = "https://weatherapi.pelmorex.com/api"
    private static let searchBase = "https://pelmsearch.pelmorex.com/api/appframework/search"
    private static let healthBase = "https://services.pelmorex.com"
    private static let locale = "en-CA"
    private static var unit: String { UserDefaults.standard.string(forKey: "unitSystem") ?? "metric" }

    // MARK: - Response Cache

    private final class CacheEntry: @unchecked Sendable {
        let data: Data
        let timestamp: Date
        init(data: Data) {
            self.data = data
            self.timestamp = Date()
        }
    }

    private static let cacheTTL: TimeInterval = 300 // 5 minutes
    private static let errorCacheTTL: TimeInterval = 60 // 1 minute for error responses
    private nonisolated(unsafe) static var cache: [String: CacheEntry] = [:]
    private nonisolated(unsafe) static var rateLimitedUntil: Date?
    private nonisolated(unsafe) static var cacheLock = NSLock()

    private static func cachedData(for key: String) -> Data? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let entry = cache[key],
              Date().timeIntervalSince(entry.timestamp) < cacheTTL else {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }

    private static func storeInCache(_ data: Data, for key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache[key] = CacheEntry(data: data)
    }

    static func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll()
        rateLimitedUntil = nil
    }

    // MARK: - Network Layer

    nonisolated private static func makeRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue("reactweb", forHTTPHeaderField: "pelmorex-client")
        req.setValue("2.0.0", forHTTPHeaderField: "pelmorex-client-version")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10
        return req
    }

    nonisolated private static func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let cacheKey = url.absoluteString
        let path = url.path

        // Short-circuit if we're rate-limited
        cacheLock.lock()
        if let until = rateLimitedUntil, Date() < until {
            cacheLock.unlock()
            throw WeatherClientError.rateLimited
        }
        cacheLock.unlock()

        // Return cached response if valid
        if let cached = cachedData(for: cacheKey) {
            return try JSONDecoder().decode(T.self, from: cached)
        }

        let start = ContinuousClock.now
        do {
            let (data, response) = try await URLSession.shared.data(for: makeRequest(url: url))
            let elapsed = ContinuousClock.now - start
            let ms = Int(elapsed.components.seconds * 1000)
                + Int(Double(elapsed.components.attoseconds) / 1e15)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            await MainActor.run {
                AppLogger.shared.log("\(status) \(path) (\(ms)ms, \(data.count)B)", category: .api)
            }
            if status == 403 {
                // Remember the rate limit so we don't keep hammering
                cacheLock.lock()
                rateLimitedUntil = Date().addingTimeInterval(errorCacheTTL)
                cacheLock.unlock()
                throw WeatherClientError.rateLimited
            } else if status >= 400 {
                throw WeatherClientError.serverError(status)
            }
            storeInCache(data, for: cacheKey)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let elapsed = ContinuousClock.now - start
            let ms = Int(elapsed.components.seconds * 1000)
                + Int(Double(elapsed.components.attoseconds) / 1e15)
            await MainActor.run {
                AppLogger.shared.log("FAIL \(path) (\(ms)ms) \(error.localizedDescription)", category: .api)
            }
            throw error
        }
    }

    nonisolated private static func buildURL(base: String, path: String, params: [String: String]) throws -> URL {
        guard var components = URLComponents(string: "\(base)\(path)") else {
            throw WeatherClientError.invalidURL
        }
        // Sort query params so cache keys are deterministic regardless of dictionary ordering
        components.queryItems = params.sorted(by: { $0.key < $1.key })
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw WeatherClientError.invalidURL }
        return url
    }

    // MARK: - Location Search

    nonisolated static func searchLocation(query: String) async throws -> [Location] {
        let url = try buildURL(base: searchBase, path: "/getdata", params: [
            "keyword": query,
            "locale": locale,
        ])
        let response = try await fetch(APIResponse.Search.self, from: url)
        let results = response.profile?.flatMap { $0.location ?? [] } ?? []
        if UserDefaults.standard.object(forKey: "canadianCitiesOnly") == nil || UserDefaults.standard.bool(forKey: "canadianCitiesOnly") {
            return results.filter { $0.country == "Canada" }
        }
        return results
    }

    nonisolated static func getLocationByCode(_ code: String) async throws -> Location {
        let url = try buildURL(base: searchBase, path: "/getdatabycode", params: [
            "keyword": code,
            "locale": locale,
        ])
        let response = try await fetch(APIResponse.Search.self, from: url)
        guard let loc = response.profile?.first?.location?.first else {
            throw WeatherClientError.noData
        }
        return loc
    }

    // MARK: - Current Location (GeoIP)

    private struct GeoIPResponse: Decodable {
        let code: String
        let name: String
        let prov: String
        let prov_name: String?
        let country: String
        let country_name: String?
        let lat: Double
        let lng: Double
    }

    nonisolated static func getCurrentLocation() async throws -> Location {
        guard let url = URL(string: "\(healthBase)/geoip/\(locale)/locate") else {
            throw WeatherClientError.invalidURL
        }
        let r = try await fetch(GeoIPResponse.self, from: url)
        return Location(
            code: r.code,
            name: r.name,
            province: r.prov_name ?? r.prov,
            country: r.country_name ?? r.country,
            latitude: r.lat,
            longitude: r.lng,
            timezone: ""
        )
    }

    // MARK: - Current Conditions

    nonisolated static func getCurrent(lat: Double, lon: Double) async throws -> CurrentWeather {
        let url = try buildURL(base: weatherBase, path: "/v1/observation", params: [
            "locale": locale, "lat": String(lat), "long": String(lon), "unit": unit,
        ])
        let r = try await fetch(APIResponse.Observation.self, from: url)
        let obs = r.observation
        return CurrentWeather(
            timeLocal: obs.time.local,
            weather: obs.weatherCode,
            temperature: obs.temperature,
            dewPoint: obs.dewPoint,
            feelsLike: obs.feelsLike,
            wind: obs.wind,
            humidity: obs.relativeHumidity,
            pressure: obs.pressure.value,
            visibility: obs.visibility,
            ceiling: obs.ceiling
        )
    }

    // MARK: - Short-Term (Hourly) Forecast

    nonisolated static func getShortTerm(lat: Double, lon: Double, count: Int = 24) async throws -> [HourlyPeriod] {
        let url = try buildURL(base: weatherBase, path: "/v1/shortterm", params: [
            "locale": locale, "lat": String(lat), "long": String(lon),
            "unit": unit, "count": String(count),
        ])
        let r = try await fetch(APIResponse.ShortTerm.self, from: url)
        return r.shortTerm.enumerated().map { index, p in
            HourlyPeriod(
                id: index,
                timeLocal: p.time.local,
                weather: p.weatherCode,
                temperature: p.temperature.value,
                feelsLike: p.feelsLike,
                wind: p.wind,
                pop: p.pop ?? 0,
                humidity: p.relativeHumidity ?? 0,
                rain: p.rain ?? Precipitation(),
                snow: p.snow ?? Precipitation()
            )
        }
    }

    // MARK: - Long-Term (Daily) Forecast

    nonisolated static func getLongTerm(lat: Double, lon: Double, count: Int = 15) async throws -> [DailyForecast] {
        let url = try buildURL(base: weatherBase, path: "/v1/longterm", params: [
            "locale": locale, "lat": String(lat), "long": String(lon),
            "unit": unit, "count": String(count), "offset": "0",
        ])
        let r = try await fetch(APIResponse.LongTerm.self, from: url)
        return r.longTerm.map { d in
            DailyForecast(
                id: d.time.local,
                dateLocal: d.time.local,
                maxTemperature: d.maxTemperature,
                minTemperature: d.minTemperature,
                totalRain: d.rain ?? Precipitation(),
                totalSnow: d.snow ?? Precipitation(),
                hoursOfSun: d.hoursOfSun,
                day: DayNightForecast(
                    weather: d.day.weatherCode, temperature: d.day.temperature.value,
                    feelsLike: d.day.feelsLike, wind: d.day.wind,
                    pop: d.day.pop ?? 0, humidity: d.day.relativeHumidity ?? 0,
                    rain: d.day.rain ?? Precipitation(), snow: d.day.snow ?? Precipitation()
                ),
                night: DayNightForecast(
                    weather: d.night.weatherCode, temperature: d.night.temperature.value,
                    feelsLike: d.night.feelsLike, wind: d.night.wind,
                    pop: d.night.pop ?? 0, humidity: d.night.relativeHumidity ?? 0,
                    rain: d.night.rain ?? Precipitation(), snow: d.night.snow ?? Precipitation()
                )
            )
        }
    }

    // MARK: - Sunrise & Sunset

    nonisolated static func getSunriseSunset(lat: Double, lon: Double) async throws -> SunriseSunset {
        let url = try buildURL(base: weatherBase, path: "/v1/astronomy/sunrisesunset", params: [
            "lat": String(lat), "long": String(lon),
        ])
        let r = try await fetch(APIResponse.Astronomy.self, from: url)
        guard let times = r.times.first else { throw WeatherClientError.noData }
        return SunriseSunset(sunrise: times.sunrise, sunset: times.sunset)
    }

    // MARK: - UV Index

    nonisolated static func getUV(lat: Double, lon: Double) async throws -> UVIndex {
        let url = try buildURL(base: weatherBase, path: "/v1/uv/observation", params: [
            "lat": String(lat), "long": String(lon), "locale": locale,
        ])
        let r = try await fetch(APIResponse.UV.self, from: url)
        return UVIndex(
            index: r.uvObservation.index.value,
            level: r.uvObservation.index.text,
            source: r.source?.text ?? ""
        )
    }

    // MARK: - Air Quality

    nonisolated static func getAirQuality(placeCode: String) async throws -> AirQuality {
        let url = try buildURL(base: weatherBase, path: "/v1/airquality/observation", params: [
            "placecode": placeCode, "locale": locale,
        ])
        let r = try await fetch(APIResponse.AirQualityObs.self, from: url)
        let obs = r.airQualityObservation
        return AirQuality(
            index: obs.index.value, category: obs.index.text,
            pollutant: obs.pollutionCode?.text, source: obs.source?.text
        )
    }

    // MARK: - Historical (Yesterday)

    nonisolated static func getYesterday(lat: Double, lon: Double) async throws -> [HistoricalTemperature] {
        let url = try buildURL(base: weatherBase, path: "/v1/historical/temperature", params: [
            "locale": locale, "lat": String(lat), "long": String(lon), "unit": unit,
        ])
        let r = try await fetch(APIResponse.Historical.self, from: url)
        return (r.history ?? []).map { h in
            HistoricalTemperature(
                id: h.timestamp, date: h.timestamp,
                high: h.temperature.maximum, low: h.temperature.minimum
            )
        }
    }

    // MARK: - Pollen

    nonisolated static func getPollen(lat: Double, lon: Double) async throws -> PollenObservation {
        let url = try buildURL(base: weatherBase, path: "/v3/allergen/pollen/observation", params: [
            "lat": String(lat), "long": String(lon), "locale": locale.lowercased(),
        ])
        let r = try await fetch(APIResponse.PollenResponse.self, from: url)
        let obs = r.pollenObservation
        return PollenObservation(
            index: obs.index.value,
            level: obs.index.text,
            source: r.source?.text ?? "",
            species: obs.species?.map(\.name) ?? []
        )
    }

    // MARK: - Health Indices

    nonisolated static func getHealthIndices(placeCode: String) async throws -> [HealthIndex] {
        let url = try buildURL(base: healthBase, path: "/health/v1/all/\(locale)/\(placeCode)", params: [
            "count": "4",
        ])
        let r = try await fetch(APIResponse.HealthIndicesResponse.self, from: url)
        let currentHour = Calendar.current.component(.hour, from: Date())
        let targetPeriod = switch currentHour {
        case 0..<6: 1
        case 6..<12: 2
        case 12..<18: 3
        default: 4
        }

        let displayNames: [String: String] = [
            "migraine": "Migraine", "joint": "Joint Pain",
            "common_cold": "Cold & Flu", "flu": "Flu",
            "sinus": "Sinus", "outdoor_fitness": "Outdoor Fitness",
        ]

        return r.categories.compactMap { category, entries in
            guard let entry = entries.first(where: { $0.period == targetPeriod }) ?? entries.last,
                  entry.risk != "NO" else { return nil }
            let name = displayNames[category] ?? category.replacingOccurrences(of: "_", with: " ").capitalized
            return HealthIndex(id: category, name: name, risk: entry.risk_label, value: entry.value)
        }.sorted { $0.value > $1.value }
    }

    // MARK: - Monthly Averages

    nonisolated static func getMonthlyAverages(lat: Double, lon: Double) async throws -> MonthlyAverage {
        let now = Date()
        let cal = Calendar.current
        let url = try buildURL(base: weatherBase, path: "/v1/historical/averages/daily", params: [
            "locale": locale, "lat": String(lat), "long": String(lon),
            "unit": unit, "month": String(cal.component(.month, from: now)),
            "year": String(cal.component(.year, from: now)),
        ])
        let r = try await fetch(APIResponse.AveragesResponse.self, from: url)
        let days = r.days ?? []
        guard !days.isEmpty else { throw WeatherClientError.noData }
        let count = Double(days.count)
        return MonthlyAverage(
            avgHigh: days.compactMap(\.temperatureMax).reduce(0, +) / count,
            avgLow: days.compactMap(\.temperatureMin).reduce(0, +) / count,
            avgHumidity: days.compactMap(\.relativeHumidity).reduce(0, +) / count,
            totalRain: days.compactMap { $0.rain?.value }.reduce(0, +),
            totalSnow: days.compactMap { $0.snow?.value }.reduce(0, +)
        )
    }

    // MARK: - Weather Alerts

    nonisolated static func getAlerts(lat: Double, lon: Double) async throws -> [WeatherAlert] {
        let url = try buildURL(base: weatherBase, path: "/v1/alert", params: [
            "lat": String(lat), "long": String(lon), "locale": locale,
        ])
        let r = try await fetch(APIResponse.AlertResponse.self, from: url)
        return r.alerts.enumerated().map { index, a in
            WeatherAlert(
                id: a.id ?? "\(index)",
                title: a.name ?? "Weather Alert",
                description: a.message ?? "",
                severity: a.priority ?? "Unknown",
                issuedTime: a.issuedTime?.local ?? "",
                expiryTime: a.expirationTime?.local ?? "",
                url: "https://weather.gc.ca/?layers=alert"
            )
        }
    }

    // MARK: - Daily Climate Averages

    nonisolated static func getDailyAverages(lat: Double, lon: Double) async throws -> [DailyAverage] {
        let now = Date()
        let cal = Calendar.current
        let url = try buildURL(base: weatherBase, path: "/v1/historical/averages/daily", params: [
            "locale": locale, "lat": String(lat), "long": String(lon),
            "unit": unit, "month": String(cal.component(.month, from: now)),
            "year": String(cal.component(.year, from: now)),
        ])
        let r = try await fetch(APIResponse.AveragesResponse.self, from: url)
        return (r.days ?? []).enumerated().compactMap { index, day in
            guard let high = day.temperatureMax, let low = day.temperatureMin else { return nil }
            let date = day.timestamp ?? "\(index + 1)"
            return DailyAverage(
                id: date,
                date: date,
                high: high,
                low: low,
                precipFrequency: day.precipitationFrequency ?? 0
            )
        }
    }

    // MARK: - Combined Fetch

    nonisolated static func getAll(lat: Double, lon: Double, placeCode: String?) async throws -> AllWeatherData {
        async let c = getCurrent(lat: lat, lon: lon)
        async let h = getShortTerm(lat: lat, lon: lon)
        async let d = getLongTerm(lat: lat, lon: lon)
        async let s = getSunriseSunset(lat: lat, lon: lon)
        async let u = getUV(lat: lat, lon: lon)
        async let y = getYesterday(lat: lat, lon: lon)
        async let p = getPollen(lat: lat, lon: lon)
        async let avg = getMonthlyAverages(lat: lat, lon: lon)
        async let alerts = getAlerts(lat: lat, lon: lon)
        async let dailyAvg = getDailyAverages(lat: lat, lon: lon)

        let aq: AirQuality?
        let hi: [HealthIndex]
        if let code = placeCode {
            aq = try? await getAirQuality(placeCode: code)
            hi = (try? await getHealthIndices(placeCode: code)) ?? []
        } else {
            aq = nil
            hi = []
        }

        let pollenResult = try? await p
        let avgResult = try? await avg
        let alertsResult = (try? await alerts) ?? []
        let dailyAvgResult = (try? await dailyAvg) ?? []

        return try await AllWeatherData(
            current: c, hourly: h, daily: d, sun: s, uv: u,
            airQuality: aq, yesterday: y,
            pollen: pollenResult, healthIndices: hi, monthlyAverage: avgResult,
            alerts: alertsResult, dailyAverages: dailyAvgResult
        )
    }
}
