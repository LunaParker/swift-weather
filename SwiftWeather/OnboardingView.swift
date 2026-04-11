import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    var onLocationSelected: (Location) -> Void

    @State private var step: OnboardingStep = .disclaimer
    @State private var searchQuery = ""
    @State private var searchResults: [Location] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedLocation: Location?

    @AppStorage("unitSystem") private var unitSystem: String = "metric"
    @AppStorage("backgroundStyle") private var backgroundStyle: String = "clear"

    private enum OnboardingStep {
        case disclaimer
        case preferences
        case location
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .disclaimer:
                disclaimerStep
            case .preferences:
                preferencesStep
            case .location:
                locationStep
            }
        }
        .frame(width: 460, height: 400)
    }

    // MARK: - Disclaimer

    private var disclaimerStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)

            Text("Before You Continue")
                .font(.title2.weight(.semibold))

            Text("""
                This application is **not affiliated with, endorsed by, or associated with Pelmorex Corp. or The Weather Network** in any way.

                Weather data is retrieved from an undocumented API. This app is intended for **personal use only**. By continuing, you acknowledge that you use this application and its data **at your own risk**.

                The developer assumes no responsibility for misuse of Pelmorex APIs.
                """)
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Button {
                withAnimation {
                    step = .preferences
                }
            } label: {
                Text("I Understand")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Preferences

    private var preferencesStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "gearshape.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Preferences")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Units")
                        .font(.headline)
                    Picker("Units", selection: $unitSystem) {
                        Text("Metric (°C, km/h, mm)").tag("metric")
                        Text("Imperial (°F, mph, in)").tag("imperial")
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Background")
                        .font(.headline)
                    Picker("Background", selection: $backgroundStyle) {
                        Text("Clear — more transparent, desktop visible through window").tag("clear")
                        Text("Frosted — subtle tint for better contrast and readability").tag("frosted")
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            Button {
                withAnimation {
                    step = .location
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Location

    private var locationStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("Set Your Location")
                .font(.title2.weight(.semibold))

            Text("Search for your city to get started.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Search for a city…", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
                .onChange(of: searchQuery) {
                    performSearch()
                }

            if !searchResults.isEmpty {
                List(searchResults) { location in
                    Button {
                        selectedLocation = location
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
                            Spacer()
                            if selectedLocation?.code == location.code {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 40)
            }

            Spacer()

            Button {
                if let location = selectedLocation {
                    onLocationSelected(location)
                }
                isPresented = false
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedLocation == nil)
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Search

    private func performSearch() {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let results = try await WeatherClient.searchLocation(query: query)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                if !Task.isCancelled { searchResults = [] }
            }
        }
    }
}
