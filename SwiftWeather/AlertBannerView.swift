import SwiftUI
import FoundationModels

struct AlertBannerView: View {
    let alerts: [WeatherAlert]
    @State private var expandedAlertID: String?
    @State private var summaries: [String: String] = [:]
    @State private var generatingIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 10) {
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
        let bg = alertColor(for: alert.severity)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedAlertID = isExpanded ? nil : alert.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: alertIcon(for: alert.severity))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        if !alert.expiryTime.isEmpty {
                            Text("Expires at \(formatAlertTime(alert.expiryTime))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent(for: alert)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(bg)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: bg.opacity(0.35), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private func expandedContent(for alert: WeatherAlert) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().background(.white.opacity(0.25))

            if let summary = summaries[alert.id] {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.95))
                }
            } else if generatingIDs.contains(alert.id) {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                    Text("Summarizing with Apple Intelligence…")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            if !alert.description.isEmpty {
                Text(alert.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }

            if !alert.issuedTime.isEmpty {
                Label("Issued \(formatAlertTime(alert.issuedTime))", systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }

            if let url = URL(string: alert.url) {
                Link(destination: url) {
                    Label("View on Environment Canada", systemImage: "arrow.up.right.square")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func alertIcon(for severity: String) -> String {
        switch severity.lowercased() {
        case "extreme", "severe": return "exclamationmark.triangle.fill"
        case "moderate":          return "exclamationmark.circle.fill"
        default:                  return "info.circle.fill"
        }
    }

    private func alertColor(for severity: String) -> Color {
        switch severity.lowercased() {
        case "extreme": return CarrotStyle.alertRed
        case "severe":  return CarrotStyle.alertOrange
        case "moderate": return CarrotStyle.alertYellow
        default:        return CarrotStyle.accent
        }
    }

    private func formatAlertTime(_ isoString: String) -> String {
        formatTime(isoString)
    }
}
