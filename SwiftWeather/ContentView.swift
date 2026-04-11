import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
struct DesktopTintedBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        DispatchQueue.main.async {
            view.window?.isOpaque = false
            view.window?.backgroundColor = .clear
        }
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#endif

struct ContentView: View {
    @State private var viewModel = WeatherViewModel()
    @State private var scrolledPastHeader = false
    @AppStorage("temperatureDisplay") private var temperatureDisplay: String = "current"
    @AppStorage("backgroundStyle") private var backgroundStyle: String = "clear"
    @AppStorage("unitSystem") private var unitSystem: String = "metric"
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var showOnboarding = false
    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.colorScheme) private var colorScheme

    /// Whether the effective background behind the header text is light.
    /// In "clear" background style the gradient sits at 15% opacity and the
    /// underlying system chrome dominates, so we defer to the system color
    /// scheme. In "frosted" style the gradient contributes meaningfully, so
    /// we only treat the background as light when BOTH the system is in
    /// light mode AND the current weather gradient is itself light — that
    /// way dark-mode users never get black text on a dark blend.
    private var lightBackground: Bool {
        guard colorScheme == .light else { return false }
        guard backgroundStyle == "frosted" else { return true }
        guard let icon = viewModel.weather?.current.weather.icon else { return true }
        return isLightBackground(for: icon)
    }
    private var headerPrimary: Color { lightBackground ? .black : .white }
    private var headerSecondary: Color { lightBackground ? .black.opacity(0.6) : .white.opacity(0.7) }
    private var headerTertiary: Color { lightBackground ? .black.opacity(0.45) : .white.opacity(0.5) }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle(viewModel.selectedLocation?.name ?? "Weather")
                #if os(macOS)
                .toolbarBackgroundVisibility(scrolledPastHeader ? .visible : .hidden, for: .windowToolbar)
                #endif
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            Task { await viewModel.refreshWeather() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .keyboardShortcut("r", modifiers: .command)
                        .disabled(viewModel.isLoading || viewModel.selectedLocation == nil)
                    }
                }
                .searchable(text: $viewModel.searchQuery, prompt: "Search for a city...")
                .searchSuggestions {
                    ForEach(viewModel.searchResults) { location in
                        Button {
                            dismissSearch()
                            viewModel.selectLocation(location)
                        } label: {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(location.name)
                                    Text(location.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .onChange(of: viewModel.searchQuery) {
                    viewModel.search()
                }
                .onChange(of: unitSystem) {
                    Task { await viewModel.refreshWeather() }
                }
                .task {
                    viewModel.loadRecentWeather()
                }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 600)
        #endif
        .onAppear {
            if !onboardingComplete {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding) { location in
                onboardingComplete = true
                viewModel.selectLocation(location)
            }
            .interactiveDismissDisabled(!onboardingComplete)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            #if os(macOS)
            DesktopTintedBackground()
                .ignoresSafeArea()
            #endif

            backgroundGradient
                .opacity(backgroundStyle == "frosted" ? 0.45 : 0.15)
                .ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
                    .onAppear { scrolledPastHeader = false }
            } else if let weather = viewModel.weather,
                      let location = viewModel.selectedLocation {
                weatherScrollView(weather: weather, location: location)
            } else if let error = viewModel.errorMessage {
                errorView(error)
                    .onAppear { scrolledPastHeader = false }
            } else {
                emptyStateView
                    .onAppear { scrolledPastHeader = false }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        Group {
            if let weather = viewModel.weather {
                weatherGradient(for: weather.current.weather.icon)
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.45, blue: 0.92),
                        Color(red: 0.42, green: 0.72, blue: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
    }

    // MARK: - Weather Content

    private func weatherScrollView(weather: AllWeatherData, location: Location) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                locationHeader(weather: weather, location: location)
                    .padding(.bottom, 24)

                VStack(spacing: 16) {
                    if !weather.alerts.isEmpty {
                        AlertBannerView(alerts: weather.alerts)
                    }
                    DayOverviewCard(hourly: weather.hourly, daily: weather.daily)
                    HourlyForecastView(periods: weather.hourly)
                    PrecipitationCard(hourly: weather.hourly, daily: weather.daily)
                    DailyForecastView(days: weather.daily)
                    infoCardsGrid(weather: weather)
                }
                .padding(.horizontal, 20)

                attributionLink(for: location)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
            }
        }
        .refreshable {
            await viewModel.refreshWeather()
        }
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y > 30
        } action: { _, isPastHeader in
            withAnimation(.easeInOut(duration: 0.25)) {
                scrolledPastHeader = isPastHeader
            }
        }
    }

    private func locationHeader(weather: AllWeatherData, location: Location) -> some View {
        let showFeelsLike = temperatureDisplay == "feelsLike"
        let prominentTemp = showFeelsLike ? weather.current.feelsLike : weather.current.temperature
        let secondaryTemp = showFeelsLike ? weather.current.temperature : weather.current.feelsLike
        let secondaryLabel = showFeelsLike ? "Actual" : "Feels like"

        let primary = headerPrimary
        let secondary = headerSecondary
        let tertiary = headerTertiary

        return ViewThatFits(in: .horizontal) {
            // Wide layout: 2 columns
            HStack(alignment: .top, spacing: 16) {
                temperatureColumn(prominentTemp: prominentTemp, icon: weather.current.weather.icon, color: primary)
                detailsColumn(
                    location: location, weather: weather,
                    secondaryLabel: secondaryLabel, secondaryTemp: secondaryTemp,
                    primary: primary, secondary: secondary, tertiary: tertiary
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Narrow layout: stacked
            VStack(alignment: .leading, spacing: 6) {
                temperatureColumn(prominentTemp: prominentTemp, icon: weather.current.weather.icon, color: primary)
                detailsColumn(
                    location: location, weather: weather,
                    secondaryLabel: secondaryLabel, secondaryTemp: secondaryTemp,
                    primary: primary, secondary: secondary, tertiary: tertiary
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private func temperatureColumn(prominentTemp: Double, icon: Int, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(Int(prominentTemp.rounded()))°")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(color)
            Image(systemName: weatherSymbol(for: icon))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 28))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 4 }
        }
    }

    private func detailsColumn(location: Location, weather: AllWeatherData, secondaryLabel: String, secondaryTemp: Double, primary: Color, secondary: Color, tertiary: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(location.name)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(primary)
            Text(location.subtitle)
                .font(.subheadline)
                .foregroundStyle(secondary)
            Text(weather.current.weather.text)
                .font(.body)
                .foregroundStyle(lightBackground ? primary.opacity(0.75) : primary.opacity(0.85))
                .padding(.top, 1)
            HStack(spacing: 8) {
                Text("\(secondaryLabel) \(Int(secondaryTemp.rounded()))°")
                if let today = weather.daily.first {
                    Text("·")
                        .foregroundStyle(tertiary)
                    Text("H:\(Int(today.day.temperature.rounded()))°  L:\(Int(today.night.temperature.rounded()))°")
                }
            }
            .font(.caption)
            .foregroundStyle(secondary)
        }
    }

    private func infoCardsGrid(weather: AllWeatherData) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 260), spacing: 16)],
            spacing: 16
        ) {
            FeelsLikeCard(feelsLike: weather.current.feelsLike, actual: weather.current.temperature)
            WindCard(wind: weather.current.wind)
            UVIndexCard(data: weather.uv)
            SunriseSunsetCard(data: weather.sun)
            HumidityCard(humidity: weather.current.humidity, dewPoint: weather.current.dewPoint)
            PressureCard(pressure: weather.current.pressure)
            VisibilityCard(visibility: weather.current.visibility)
            if let aq = weather.airQuality {
                AirQualityCard(data: aq)
            }
            if let pollen = weather.pollen {
                PollenCard(data: pollen)
            }
            if !weather.healthIndices.isEmpty {
                HealthCard(indices: weather.healthIndices)
            }
            if let avg = weather.monthlyAverage {
                MonthlyAverageCard(data: avg, dailyAverages: weather.dailyAverages)
            }
            if !weather.yesterday.isEmpty {
                YesterdayCard(data: weather.yesterday)
            }
        }
    }

    // MARK: - Attribution

    private func attributionLink(for location: Location) -> some View {
        let citySlug = location.name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
        let province = location.province.lowercased()
            .replacingOccurrences(of: " ", with: "-")
        let urlString = "https://www.theweathernetwork.com/en/city/ca/\(province)/\(citySlug)/current"

        return Link(destination: URL(string: urlString)!) {
            HStack(spacing: 5) {
                Text("Powered by The Weather Network")
                Image(systemName: "arrow.up.right")
            }
            .font(.caption)
            .foregroundStyle(headerTertiary)
        }
    }

    // MARK: - States

    @ViewBuilder
    private var emptyStateView: some View {
        let currentCode = viewModel.currentLocationWeather?.location.code
        let filteredRecents = viewModel.recentWeather.filter { $0.location.code != currentCode }
        let hasAnything = viewModel.currentLocationWeather != nil
            || viewModel.isLoadingCurrentLocation
            || !filteredRecents.isEmpty

        if !hasAnything {
            VStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("Search for a city")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.primary)
                Text("Type a city name above to view its weather")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let current = viewModel.currentLocationWeather {
                        Button {
                            viewModel.selectLocation(current.location)
                        } label: {
                            recentLocationCard(current, isCurrentLocation: true)
                        }
                        .buttonStyle(.plain)
                    } else if viewModel.isLoadingCurrentLocation {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Detecting your location…")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(in: .rect(cornerRadius: 16))
                    }

                    if !filteredRecents.isEmpty {
                        Text("Recent Locations")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.top, 8)

                        ForEach(filteredRecents) { recent in
                            Button {
                                viewModel.selectLocation(recent.location)
                            } label: {
                                recentLocationCard(recent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
    }

    private func recentLocationCard(_ recent: RecentLocationWeather, isCurrentLocation: Bool = false) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(recent.location.name)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.primary)
                }
                Text(recent.location.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let current = recent.current, !current.weather.text.isEmpty {
                    Text(current.weather.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if recent.isLoading {
                ProgressView()
            } else if let current = recent.current {
                HStack(spacing: 12) {
                    Image(systemName: weatherSymbol(for: current.weather.icon))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 28))

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(current.temperature.rounded()))°")
                            .font(.title.weight(.light))
                            .foregroundStyle(.primary)
                        if let hi = recent.highTemp, let lo = recent.lowTemp {
                            Text("H:\(Int(hi.rounded()))° L:\(Int(lo.rounded()))°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
        .contentShape(Rectangle())
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading weather data...")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.isRateLimited ? "hand.raised.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(viewModel.isRateLimited ? "API Rate Limited" : "Unable to load weather")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                viewModel.retry()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
