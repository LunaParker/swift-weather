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
            view.window?.setFrameAutosaveName("MainWindow")
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
    @State private var isSearchPresented = false
    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.colorScheme) private var colorScheme

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
                .searchable(text: $viewModel.searchQuery, isPresented: $isSearchPresented, prompt: "Search for a city...")
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

            // Solid screen background — the Carrot look
            CarrotStyle.screenBackground(colorScheme)
                .ignoresSafeArea()

            // Soft gradient halo behind the hero — fades into the screen bg
            heroBackdrop
                .ignoresSafeArea()

            Group {
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

            // Floating search pill — visible whenever we have a location selected
            if viewModel.selectedLocation != nil {
                floatingSearchPill
            }
        }
    }

    // MARK: - Hero backdrop

    private var heroBackdrop: some View {
        GeometryReader { geo in
            let iconCode = viewModel.weather?.current.weather.icon ?? 1
            let gradient = weatherGradient(for: iconCode)
            let isLight = isLightBackground(for: iconCode)
            let intensity: Double = backgroundStyle == "frosted" ? 0.50 : 0.30

            // The weather gradient occupies the top ~45% and fades to the
            // screen background colour beneath. Dark mode keeps the band
            // tighter so it doesn't dominate.
            let bandHeight = geo.size.height * (colorScheme == .dark ? 0.35 : 0.45)

            ZStack(alignment: .top) {
                gradient
                    .frame(height: bandHeight)
                    .mask(
                        LinearGradient(
                            colors: [
                                .black.opacity(intensity),
                                .black.opacity(intensity * 0.6),
                                .clear,
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .opacity(isLight ? 0.7 : 1.0)
            }
        }
    }

    // MARK: - Weather Content

    private func weatherScrollView(weather: AllWeatherData, location: Location) -> some View {
        GeometryReader { geo in
            if geo.size.width >= 900 {
                wideWeatherLayout(weather: weather, location: location)
            } else {
                narrowWeatherLayout(weather: weather, location: location)
            }
        }
    }

    // MARK: - Wide Layout (two-column)

    private func wideWeatherLayout(weather: AllWeatherData, location: Location) -> some View {
        let showFeelsLike = temperatureDisplay == "feelsLike"
        let prominentTemp = showFeelsLike ? weather.current.feelsLike : weather.current.temperature
        let secondaryTemp = showFeelsLike ? weather.current.temperature : weather.current.feelsLike
        let secondaryLabel = showFeelsLike ? "Actual" : "Feels like"
        let today = weather.daily.first

        return HStack(spacing: 0) {
            VStack(alignment: .center, spacing: 0) {
                Spacer()
                heroBlock(
                    location: location,
                    weather: weather,
                    prominentTemp: prominentTemp,
                    secondaryLabel: secondaryLabel,
                    secondaryTemp: secondaryTemp,
                    today: today,
                    alignment: .center
                )
                Spacer()
                attributionLink(for: location)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)

            ScrollView {
                VStack(spacing: 16) {
                    if !weather.alerts.isEmpty {
                        AlertBannerView(alerts: weather.alerts)
                    }
                    DayOverviewCard(hourly: weather.hourly, daily: weather.daily)
                    PrecipitationCard(hourly: weather.hourly, daily: weather.daily)
                    HourlyForecastView(periods: weather.hourly)
                    DailyForecastView(days: weather.daily)
                    infoCardsGrid(weather: weather)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity)
            .scrollContentBackground(.hidden)
            .refreshable {
                await viewModel.refreshWeather()
            }
        }
        .onAppear { scrolledPastHeader = false }
    }

    // MARK: - Narrow Layout (single-column scroll)

    private func narrowWeatherLayout(weather: AllWeatherData, location: Location) -> some View {
        let showFeelsLike = temperatureDisplay == "feelsLike"
        let prominentTemp = showFeelsLike ? weather.current.feelsLike : weather.current.temperature
        let secondaryTemp = showFeelsLike ? weather.current.temperature : weather.current.feelsLike
        let secondaryLabel = showFeelsLike ? "Actual" : "Feels like"
        let today = weather.daily.first

        return ScrollView {
            VStack(spacing: 0) {
                heroBlock(
                    location: location,
                    weather: weather,
                    prominentTemp: prominentTemp,
                    secondaryLabel: secondaryLabel,
                    secondaryTemp: secondaryTemp,
                    today: today,
                    alignment: .center
                )
                .padding(.top, 8)
                .padding(.bottom, 24)

                VStack(spacing: 14) {
                    if !weather.alerts.isEmpty {
                        AlertBannerView(alerts: weather.alerts)
                    }
                    DayOverviewCard(hourly: weather.hourly, daily: weather.daily)
                    PrecipitationCard(hourly: weather.hourly, daily: weather.daily)
                    HourlyForecastView(periods: weather.hourly)
                    DailyForecastView(days: weather.daily)
                    infoCardsGrid(weather: weather)
                }
                .padding(.horizontal, 16)

                attributionLink(for: location)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
            }
        }
        .scrollContentBackground(.hidden)
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

    // MARK: - Carrot-style hero

    @ViewBuilder
    private func heroBlock(
        location: Location,
        weather: AllWeatherData,
        prominentTemp: Double,
        secondaryLabel: String,
        secondaryTemp: Double,
        today: DailyForecast?,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(location.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(location.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(Int(prominentTemp.rounded()))°")
                .font(.system(size: 88, weight: .thin))
                .foregroundStyle(.primary)
                .padding(.top, 6)

            if let today {
                HStack(spacing: 6) {
                    Label("\(Int(today.day.temperature.rounded()))°", systemImage: "arrow.up")
                        .labelStyle(.titleAndIcon)
                    Label("\(Int(today.night.temperature.rounded()))°", systemImage: "arrow.down")
                        .labelStyle(.titleAndIcon)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            }

            Text(conditionSummary(weather: weather, secondaryLabel: secondaryLabel, secondaryTemp: secondaryTemp))
                .font(.callout)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
    }

    private func conditionSummary(weather: AllWeatherData, secondaryLabel: String, secondaryTemp: Double) -> String {
        let text = weather.current.weather.text
        if !text.isEmpty {
            return "\(text). \(secondaryLabel) \(Int(secondaryTemp.rounded()))°."
        }
        return "\(secondaryLabel) \(Int(secondaryTemp.rounded()))°."
    }

    // MARK: - Info cards grid

    @ViewBuilder
    private func infoCardsGrid(weather: AllWeatherData) -> some View {
        VStack(spacing: 12) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
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
                if !weather.yesterday.isEmpty {
                    YesterdayCard(data: weather.yesterday)
                }
            }

            if let avg = weather.monthlyAverage {
                MonthlyAverageCard(data: avg, dailyAverages: weather.dailyAverages)
            }
        }
    }

    // MARK: - Floating search pill

    private var floatingSearchPill: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Button {
                    isSearchPresented = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                        Text("Search")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 14, x: 0, y: 4)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(true)
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
            .foregroundStyle(.tertiary)
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
                VStack(alignment: .leading, spacing: 14) {
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
                        .carrotCard()
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
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func recentLocationCard(_ recent: RecentLocationWeather, isCurrentLocation: Bool = false) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundStyle(CarrotStyle.accent)
                    }
                    Text(recent.location.name)
                        .font(.title3.weight(.semibold))
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
        .carrotCard()
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
