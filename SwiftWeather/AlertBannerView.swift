import SwiftUI

struct AlertBannerView: View {
    let alerts: [WeatherAlert]
    @State private var expandedAlertID: String?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(alerts) { alert in
                alertCard(alert)
            }
        }
    }

    private func alertCard(_ alert: WeatherAlert) -> some View {
        let isExpanded = expandedAlertID == alert.id

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedAlertID = isExpanded ? nil : alert.id
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: alertIcon(for: alert.severity))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(alertColor(for: alert.severity))

                    Text(alert.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if !alert.description.isEmpty {
                        Text(alert.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        if !alert.issuedTime.isEmpty {
                            Label(formatAlertTime(alert.issuedTime), systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if !alert.expiryTime.isEmpty {
                            Label("Until \(formatAlertTime(alert.expiryTime))", systemImage: "clock.badge.xmark")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(alertColor(for: alert.severity).opacity(0.1))
                .strokeBorder(alertColor(for: alert.severity).opacity(0.3), lineWidth: 1)
        }
    }

    private func alertIcon(for severity: String) -> String {
        switch severity.lowercased() {
        case "extreme": return "exclamationmark.triangle.fill"
        case "severe":  return "exclamationmark.triangle.fill"
        case "moderate": return "exclamationmark.circle.fill"
        default:        return "info.circle.fill"
        }
    }

    private func alertColor(for severity: String) -> Color {
        switch severity.lowercased() {
        case "extreme": return .red
        case "severe":  return .orange
        case "moderate": return .yellow
        default:        return .blue
        }
    }

    private func formatAlertTime(_ isoString: String) -> String {
        formatTime(isoString)
    }
}
