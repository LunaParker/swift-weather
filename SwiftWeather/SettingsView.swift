import SwiftUI

// MARK: - App Logger

@MainActor @Observable
final class AppLogger {
    static let shared = AppLogger()

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let category: LogCategory
        let message: String
    }

    enum LogCategory: String, CaseIterable {
        case app = "App"
        case api = "API"
    }

    private(set) var entries: [LogEntry] = []
    private let maxEntries = 500

    private init() {}

    func log(_ message: String, category: LogCategory) {
        entries.append(LogEntry(timestamp: Date(), category: category, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            LogsSettingsTab()
                .tabItem {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }
            DeveloperSettingsTab()
                .tabItem {
                    Label("Developer", systemImage: "hammer")
                }
        }
        .frame(width: 520, height: 400)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @AppStorage("temperatureDisplay") private var temperatureDisplay: String = "current"
    @AppStorage("unitSystem") private var unitSystem: String = "metric"
    @AppStorage("canadianCitiesOnly") private var canadianCitiesOnly: Bool = true
    @AppStorage("precipThreshold") private var precipThreshold: Int = 40
    @AppStorage("backgroundStyle") private var backgroundStyle: String = "clear"

    var body: some View {
        Form {
            Picker("Background style", selection: $backgroundStyle) {
                Text("Clear").tag("clear")
                Text("Frosted").tag("frosted")
            }
            .pickerStyle(.radioGroup)

            Picker("Unit system", selection: $unitSystem) {
                Text("Metric (°C, km/h)").tag("metric")
                Text("Imperial (°F, mph)").tag("imperial")
            }
            .pickerStyle(.radioGroup)

            Picker("Prominent temperature display", selection: $temperatureDisplay) {
                Text("Current Temperature").tag("current")
                Text("Feels Like").tag("feelsLike")
            }
            .pickerStyle(.radioGroup)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Canadian cities only", isOn: $canadianCitiesOnly)
                Text("When enabled, search results hide US and international cities.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Picker("Precipitation threshold", selection: $precipThreshold) {
                    Text("20%").tag(20)
                    Text("30%").tag(30)
                    Text("40%").tag(40)
                    Text("50%").tag(50)
                    Text("60%").tag(60)
                }
                .pickerStyle(.segmented)
                Text("The minimum probability of precipitation for the forecast to indicate rain is expected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Logs Tab

struct LogsSettingsTab: View {
    var logger = AppLogger.shared
    @State private var filterCategory: AppLogger.LogCategory? = nil

    private var filteredEntries: [AppLogger.LogEntry] {
        if let filter = filterCategory {
            return logger.entries.filter { $0.category == filter }
        }
        return logger.entries
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Filter", selection: $filterCategory) {
                    Text("All").tag(nil as AppLogger.LogCategory?)
                    ForEach(AppLogger.LogCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat as AppLogger.LogCategory?)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                Text("\(filteredEntries.count) entries")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Button("Clear") {
                    logger.clear()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            List(filteredEntries.reversed()) { entry in
                HStack(alignment: .top, spacing: 8) {
                    Text(Self.timestampFormatter.string(from: entry.timestamp))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 85, alignment: .leading)

                    Text(entry.category.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(entry.category == .api ? .blue : .green)
                        .frame(width: 30, alignment: .leading)

                    Text(entry.message)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Developer Tab

struct DeveloperSettingsTab: View {
    @AppStorage("useMockData") private var useMockData = false
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        Form {
            Toggle("Use Mock Data", isOn: $useMockData)
            Text("When enabled, search returns only Toronto and weather data is generated locally. No API calls are made.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Show Onboarding") {
                onboardingComplete = false
            }
            Text("Resets onboarding state. The onboarding popup will appear next time the main window is opened.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}
