# SwiftWeather - CLAUDE.md

## Project Overview

SwiftWeather is a SwiftUI weather app displaying Canadian weather data from Pelmorex's public web APIs. It targets macOS 26.4+ / iOS 26.4+ / iPadOS 26.4+ / visionOS and requires Xcode 26+. There are no external dependencies or libraries.

## File Structure

```
SwiftWeather/
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

## Pelmorex API Integration

`WeatherClient.swift` is the sole networking layer. It targets three Pelmorex hosts with no API keys or credentials required:

| Host | Purpose |
| --- | --- |
| `weatherapi.pelmorex.com` | Observations, forecasts, alerts, astronomy, UV, historical, averages |
| `pelmsearch.pelmorex.com` | City search and place-code lookup |
| `services.pelmorex.com` | Health indices, air quality targeting, and IP geolocation (`/geoip/en-CA/locate`) |

- Responses are cached for 5 minutes.
- A short-circuit is applied if the server returns HTTP 403 (rate limited).
- Locations are identified by Pelmorex place codes (e.g. `CAON0235`).
- Raw JSON responses are decoded into intermediate wrappers in the `APIResponse` enum, then flattened into app-facing domain types defined in `Models.swift`.

## Development Iteration Workflow

Use XcodeBuildMCP tools for the build-test-iterate cycle. The critical advantage is that `screenshot` returns the image directly in the tool response, so you can visually inspect the UI without leaving the conversation.

**Standard iteration loop:**

1. **Edit** SwiftUI code
2. **Build and run** on simulator via `build_run_sim`
3. **Inspect the UI** using `snapshot_ui` (view hierarchy with element coordinates) and `screenshot` (visual capture)
4. **Evaluate** the rendered result visually and iterate if needed
5. Repeat until the UI matches expectations

Before your first build in a session, call `session_show_defaults` to verify project, scheme, and simulator are configured.

## After Completing All Tasks

Once all work is done and the build succeeds:

1. **Offer to archive and install**: Build a release archive and install the app to `~/Applications`, overwriting any existing copy. Use `xcodebuild archive` and export, then copy the `.app` to `~/Applications/`.
2. **Commit and push**: Offer to commit the changes and push to the remote.
