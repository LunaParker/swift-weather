# SwiftWeather

A simple SwiftUI weather app proof-of-concept which displays Canadian weather data from Pelmorex's public web APIs.

## Features

- **Current conditions** - temperature, feels-like, humidity, dew point, pressure, visibility, wind, UV index, air quality, pollen, and weather alerts
- **Forecasts** - 24-hour hourly forecast, 15-day daily forecast, precipitation outlook, and sunrise/sunset times
- **Context cards** - yesterday's high/low, monthly climate averages, and health indices (migraine, cold & flu, joint pain, etc.)
- **Current location** - IP-based geolocation surfaces your nearest city on the start screen without any permission prompt
- **Recent locations** - quick-access cards for your most recently viewed cities with live temperature and conditions
- **Search** - city lookup with optional Canadian-only filter
- **Units** - switchable metric / imperial
- **Themes** - clear or frosted glass background styles that adapt to the current weather
- **Onboarding** - first-launch location picker
- **Mock data mode** - offline development and UI preview support

## Build

**Requirements**
- Xcode 26 or newer
- macOS 26.4+ / iOS 26.4+ / iPadOS 26.4+ / visionOS deployment targets
- Swift 5.0+

**Steps**
1. Clone this repository
2. Open `SwiftWeather.xcodeproj` in Xcode
3. Select a run destination (iPhone simulator, Mac, iPad, or Vision Pro simulator)
4. Build and run (no external dependencies/libraries)

## File Structure

```
SwiftWeather/
├── SwiftWeather.xcodeproj/          Xcode project
└── SwiftWeather/
    ├── SwiftWeatherApp.swift        App entry point, scene setup
    ├── ContentView.swift            Root view: header, scroll content, empty state, recents
    ├── OnboardingView.swift         First-launch location picker
    ├── SettingsView.swift           User preferences (units, theme, mock mode)
    │
    ├── WeatherClient.swift          Pelmorex API client (networking, caching, rate-limit handling)
    ├── WeatherViewModel.swift       @Observable state holder, search, recents, current location
    ├── Models.swift                 Domain model structs and API response decoders
    ├── MockData.swift               Offline fixture data for preview / mock mode
    ├── WeatherHelpers.swift         Icon mapping, gradient selection, formatting helpers
    │
    ├── AlertBannerView.swift        Severe weather alert banner
    ├── DayOverviewCard.swift        Today's high/low overview card
    ├── HourlyForecastView.swift     24-hour scrolling forecast
    ├── DailyForecastView.swift      Multi-day forecast list
    ├── PrecipitationCard.swift      Rain/snow outlook card
    ├── InfoCardsView.swift          Grid of info cards (wind, UV, AQ, pollen, etc.)
    │
    ├── Assets.xcassets              App icon and color assets
    └── SwiftWeather.entitlements    App sandbox + network client entitlements
```

## Data Structures

All domain types live in `Models.swift`. The client decodes Pelmorex's raw JSON into intermediate wrappers in the `APIResponse` enum and flattens them into the following app-facing types:

### Core

| Type | Description |
| --- | --- |
| `Location` | A city with place code, name, province, country, lat/lon, and timezone. `id` is the Pelmorex place code (e.g. `CAON0235`). |
| `RecentLocationWeather` | A light snapshot used for the start-screen cards: a `Location` plus its current conditions and today's high/low. |
| `AllWeatherData` | The top-level container returned by `WeatherClient.getAll(…)` - bundles every subsystem below. |

### Observations & Forecasts

| Type | Description |
| --- | --- |
| `CurrentWeather` | Temperature, feels-like, dew point, wind, humidity, pressure, visibility, ceiling, and a `WeatherCode`. |
| `HourlyPeriod` | A single hour: temperature, feels-like, wind, pop, humidity, rain, snow, weather code. |
| `DailyForecast` | A single day with `day` and `night` `DayNightForecast` splits, plus totals for rain/snow and hours of sun. |
| `DayNightForecast` | The per-half-day conditions embedded in `DailyForecast`. |

### Context & Climate

| Type | Description |
| --- | --- |
| `SunriseSunset` | Astronomical sunrise/sunset times for the selected day. |
| `UVIndex` | Numeric index, category label, and data source. |
| `AirQuality` | AQ index, category, primary pollutant, and source. |
| `PollenObservation` | Pollen index, risk level, source, and contributing species. |
| `HealthIndex` | Per-category health index (migraine, cold & flu, joint pain, outdoor fitness, sinus). |
| `HistoricalTemperature` | Yesterday's daily high/low. |
| `MonthlyAverage` | Monthly climate averages (temperature, humidity, precipitation totals). |
| `DailyAverage` | Per-day climate normals for the current month. |
| `WeatherAlert` | Severe-weather alerts (headline, severity, timing, description). |

### Shared Components

| Type | Description |
| --- | --- |
| `Wind` | Direction, speed, and optional gust. |
| `Precipitation` | Accumulation value and range label. |
| `WeatherCode` | Numeric icon id + text description used to drive SF Symbol mapping. |

### API Endpoints

`WeatherClient.swift` targets three Pelmorex hosts. Responses are cached for 5 minutes and a short-circuit is applied if the server returns HTTP 403 (rate limited):

| Host | Purpose |
| --- | --- |
| `weatherapi.pelmorex.com` | Observations, forecasts, alerts, astronomy, UV, historical, averages |
| `pelmsearch.pelmorex.com` | City search and place-code lookup |
| `services.pelmorex.com` | Health indices, air quality targeting, and IP geolocation (`/geoip/en-CA/locate`) |

## Future Plans

Ideas not yet implemented:

- **Precipitation radar** - an interactive map tile layer showing live rain/snow radar, generated from the Pelmorex tile endpoints that power theweathernetwork.com.
- **iOS target optimization** - the UI was designed for macOS, and as such, the iOS and iPadOS paths need layout tweaking.

## Disclaimer

This project is **not affiliated with, endorsed by, or associated with The Weather Network, Pelmorex, or any of their subsidiaries**. No credentials, API keys, or private endpoints are used.

This software is intended for **personal, non-commercial use only**. The author makes no warranties regarding the availability, reliability, accuracy, or continued functionality of the upstream APIs, which may change or become unavailable at any time without notice. The author disclaims all liability arising from the use of these APIs, from any rate-limiting, or terms-of-service consequences that may result, and from any decisions made on the basis of weather data shown by this app. Users are responsible for ensuring their own use complies with applicable laws and the upstream providers' terms of service.

## License

Released under the MIT License - see [LICENSE.md](LICENSE.md) for the full text.
