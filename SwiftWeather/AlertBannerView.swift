import SwiftUI
import FoundationModels

struct AlertBannerView: View {
    let alerts: [WeatherAlert]
    @State private var expandedAlertID: String?
    @State private var summaries: [String: String] = [:]
    @State private var generatingIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 8) {
            ForEach(alerts) { alert in
                alertCard(alert)
                    .task { await generateSummary(for: alert) }
            }
        }
    }

    // MARK: - AI Summary

    private func generateSummary(for alert: WeatherAlert) async {
        guard !alert.description.isEmpty,
              summaries[alert.id] == nil,
              !generatingIDs.contains(alert.id) else { return }

        guard SystemLanguageModel.default.isAvailable else { return }

        generatingIDs.insert(alert.id)
        defer { generatingIDs.remove(alert.id) }

        do {
            let session = LanguageModelSession(instructions: """
                You summarize weather alerts in 1 to 2 short sentences. \
                Focus on what is happening, when, and how much. \
                Be direct and factual. Do not include any advice or recommendations.
                """)
            let response = try await session.respond(to: alert.description)
            let content = response.content
            withAnimation(.easeInOut(duration: 0.3)) {
                summaries[alert.id] = content
            }
        } catch {
            // Model unavailable or generation failed — no summary shown
        }
    }

    // MARK: - Card

    private func alertCard(_ alert: WeatherAlert) -> some View {
        let isExpanded = expandedAlertID == alert.id

        return VStack(alignment: .leading, spacing: 0) {
            // Tappable area — entire card except the ECCC link
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedAlertID = isExpanded ? nil : alert.id
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    // Header row
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

                    // AI summary — always visible
                    if let summary = summaries[alert.id] {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    } else if generatingIDs.contains(alert.id) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Summarizing with Apple Intelligence…")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Expanded details (description + times)
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
                        .transition(.opacity)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // ECCC link — separate from the button so it opens the URL
            if isExpanded, let url = URL(string: alert.url) {
                Link(destination: url) {
                    Label("View on Environment Canada", systemImage: "arrow.up.right.square")
                        .font(.caption2.weight(.medium))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
