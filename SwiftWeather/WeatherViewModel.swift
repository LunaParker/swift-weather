import SwiftUI

@Observable
final class WeatherViewModel {
    var searchQuery = ""
    var searchResults: [Location] = []
    var selectedLocation: Location?
    var weather: AllWeatherData?
    var isLoading = false
    var errorMessage: String?
    var isRateLimited = false
    var recentWeather: [RecentLocationWeather] = []
    var currentLocationWeather: RecentLocationWeather?
    var isLoadingCurrentLocation = false

    private var searchTask: Task<Void, Never>?
    private var recentsLoaded = false
    private static let recentsKey = "recentLocations"
    private static let maxRecents = 3

    private var useMockData: Bool {
        UserDefaults.standard.bool(forKey: "useMockData")
    }

    // MARK: - Search

    func search() {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        if useMockData {
            searchResults = MockData.searchResults(for: query)
            AppLogger.shared.log("Mock search '\(query)' → \(searchResults.count) results", category: .app)
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let results = try await WeatherClient.searchLocation(query: query)
                guard !Task.isCancelled else { return }
                searchResults = results
                AppLogger.shared.log("Search '\(query)' → \(results.count) results", category: .app)
            } catch {
                if !Task.isCancelled { searchResults = [] }
            }
        }
    }

    func selectLocation(_ location: Location) {
        AppLogger.shared.log("Selected: \(location.name) (\(location.code))", category: .app)
        selectedLocation = location
        searchResults = []
        searchQuery = ""
        addToRecents(location)
        loadWeather(for: location)
    }

    func retry() {
        guard let location = selectedLocation else { return }
        AppLogger.shared.log("Retrying: \(location.name)", category: .app)
        loadWeather(for: location)
    }

    func refreshWeather() async {
        guard let location = selectedLocation else { return }
        AppLogger.shared.log("Refreshing weather for \(location.name)", category: .app)
        WeatherClient.clearCache()
        isLoading = true
        errorMessage = nil
        isRateLimited = false
        if useMockData {
            weather = MockData.allWeather()
            isLoading = false
            return
        }
        await fetchWeather(for: location)
    }

    // MARK: - Weather Loading

    private func loadWeather(for location: Location) {
        isLoading = true
        errorMessage = nil
        isRateLimited = false
        if useMockData {
            weather = MockData.allWeather()
            AppLogger.shared.log("Mock weather loaded for \(location.name)", category: .app)
            isLoading = false
            return
        }
        Task {
            await fetchWeather(for: location)
        }
    }

    private func fetchWeather(for location: Location) async {
        do {
            let data = try await WeatherClient.getAll(
                lat: location.latitude,
                lon: location.longitude,
                placeCode: location.code
            )
            weather = data
            AppLogger.shared.log("Weather loaded for \(location.name)", category: .app)
        } catch let error as WeatherClientError where error == .rateLimited {
            isRateLimited = true
            errorMessage = error.localizedDescription
            AppLogger.shared.log("Rate limited by API", category: .app)
        } catch let DecodingError.keyNotFound(key, context) {
            errorMessage = "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            AppLogger.shared.log("Decode error: \(errorMessage!)", category: .app)
        } catch let DecodingError.valueNotFound(type, context) {
            errorMessage = "Null value for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            AppLogger.shared.log("Decode error: \(errorMessage!)", category: .app)
        } catch let DecodingError.typeMismatch(type, context) {
            errorMessage = "Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            AppLogger.shared.log("Decode error: \(errorMessage!)", category: .app)
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.shared.log("Load error: \(errorMessage!)", category: .app)
        }
        isLoading = false
    }

    // MARK: - Recents

    private var savedLocations: [Location] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.recentsKey),
                  let locations = try? JSONDecoder().decode([Location].self, from: data)
            else { return [] }
            return locations
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Self.recentsKey)
            }
        }
    }

    private func addToRecents(_ location: Location) {
        var recents = savedLocations
        recents.removeAll { $0.code == location.code }
        recents.insert(location, at: 0)
        if recents.count > Self.maxRecents {
            recents = Array(recents.prefix(Self.maxRecents))
        }
        savedLocations = recents
    }

    func loadCurrentLocation() {
        guard currentLocationWeather == nil, !isLoadingCurrentLocation else { return }
        if useMockData {
            let mockLoc = Location(
                code: "MOCK_CURRENT",
                name: "Current Location",
                province: "Ontario",
                country: "Canada",
                latitude: 43.7074,
                longitude: -80.3836,
                timezone: ""
            )
            var snapshot = RecentLocationWeather(location: mockLoc)
            let mock = MockData.allWeather()
            snapshot.current = mock.current
            snapshot.highTemp = mock.daily.first?.day.temperature
            snapshot.lowTemp = mock.daily.first?.night.temperature
            snapshot.isLoading = false
            currentLocationWeather = snapshot
            AppLogger.shared.log("Mock current location loaded", category: .app)
            return
        }
        isLoadingCurrentLocation = true
        Task {
            do {
                let location = try await WeatherClient.getCurrentLocation()
                AppLogger.shared.log("GeoIP located: \(location.name) (\(location.code))", category: .app)
                currentLocationWeather = RecentLocationWeather(location: location)
                async let current = WeatherClient.getCurrent(lat: location.latitude, lon: location.longitude)
                async let daily = WeatherClient.getLongTerm(lat: location.latitude, lon: location.longitude, count: 1)
                let c = try await current
                let d = try? await daily
                guard currentLocationWeather?.location.code == location.code else { return }
                currentLocationWeather?.current = c
                currentLocationWeather?.highTemp = d?.first?.day.temperature
                currentLocationWeather?.lowTemp = d?.first?.night.temperature
                currentLocationWeather?.isLoading = false
                isLoadingCurrentLocation = false
            } catch {
                AppLogger.shared.log("Current location failed: \(error.localizedDescription)", category: .app)
                currentLocationWeather = nil
                isLoadingCurrentLocation = false
            }
        }
    }

    func loadRecentWeather() {
        guard !recentsLoaded else { return }
        recentsLoaded = true
        loadCurrentLocation()
        let recents = savedLocations
        guard !recents.isEmpty else {
            recentWeather = []
            return
        }
        recentWeather = recents.map { RecentLocationWeather(location: $0) }
        if useMockData {
            let mock = MockData.allWeather()
            for index in recentWeather.indices {
                recentWeather[index].current = mock.current
                recentWeather[index].highTemp = mock.daily.first?.day.temperature
                recentWeather[index].lowTemp = mock.daily.first?.night.temperature
                recentWeather[index].isLoading = false
            }
            AppLogger.shared.log("Mock recent weather loaded", category: .app)
            return
        }
        for (index, loc) in recents.enumerated() {
            Task {
                do {
                    async let current = WeatherClient.getCurrent(lat: loc.latitude, lon: loc.longitude)
                    async let daily = WeatherClient.getLongTerm(lat: loc.latitude, lon: loc.longitude, count: 1)
                    let c = try await current
                    let d = try? await daily
                    guard index < recentWeather.count,
                          recentWeather[index].location.code == loc.code else { return }
                    recentWeather[index].current = c
                    recentWeather[index].highTemp = d?.first?.day.temperature
                    recentWeather[index].lowTemp = d?.first?.night.temperature
                    recentWeather[index].isLoading = false
                } catch {
                    guard index < recentWeather.count,
                          recentWeather[index].location.code == loc.code else { return }
                    recentWeather[index].isLoading = false
                    AppLogger.shared.log("Recent weather failed for \(loc.name): \(error.localizedDescription)", category: .app)
                }
            }
        }
    }
}
