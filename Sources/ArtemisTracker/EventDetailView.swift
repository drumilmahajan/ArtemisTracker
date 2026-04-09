import SwiftUI

struct EventDetailView: View {
    let event: SpaceEvent
    @State private var countdown: String = ""
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text(event.missionName ?? event.name)
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(event.provider + " · " + event.rocketName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                // Status badge
                Text(event.status.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.2))
                    .foregroundStyle(statusColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Countdown
            VStack(spacing: 6) {
                Text("LAUNCH COUNTDOWN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(countdown)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(event.timeUntilLaunch < 3600 ? .orange : .primary)

                Text(launchDateFormatted)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 20)

            Divider()

            // Mission description
            if let desc = event.missionDescription, !desc.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MISSION")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                            .lineSpacing(3)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Spacer()
            }
        }
        .frame(minWidth: 400, minHeight: 350)
        .background(.ultraThinMaterial)
        .onAppear { startCountdown() }
        .onDisappear { timer?.invalidate() }
    }

    private var statusColor: Color {
        let s = event.status.lowercased()
        if s.contains("go") { return .green }
        if s.contains("tbd") || s.contains("tbc") { return .yellow }
        if s.contains("hold") || s.contains("failure") { return .red }
        return .blue
    }

    private var launchDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter.string(from: event.net)
    }

    private func startCountdown() {
        updateCountdown()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateCountdown()
        }
    }

    private func updateCountdown() {
        countdown = event.countdownFormatted
    }
}
