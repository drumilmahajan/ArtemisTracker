import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: ArtemisViewModel
    var onToggleOverlay: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text("Artemis II Tracker")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Divider()

            if let data = viewModel.latestData {
                // Mission phase
                HStack {
                    Label(data.missionPhase, systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // Progress bar Earth → Moon
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "globe.americas.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.quaternary)
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .cyan, .white],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(8, geo.size.width * data.progressToMoon), height: 8)
                                // Spacecraft indicator
                                Image(systemName: "airplane")
                                    .font(.system(size: 10))
                                    .rotationEffect(.degrees(-45))
                                    .offset(x: max(0, geo.size.width * data.progressToMoon - 8), y: -8)
                            }
                        }
                        .frame(height: 24)
                        Image(systemName: "moon.fill")
                            .foregroundStyle(.gray)
                            .font(.caption)
                    }
                }

                // Stats grid
                VStack(spacing: 12) {
                    StatRow(icon: "globe.americas.fill", iconColor: .blue,
                            label: "From Earth", value: data.distanceFromEarthFormatted)
                    StatRow(icon: "moon.fill", iconColor: .gray,
                            label: "From Moon", value: data.distanceFromMoonFormatted)
                    StatRow(icon: "gauge.with.needle.fill", iconColor: .orange,
                            label: "Speed", value: data.speedFormatted)

                    Divider()

                    // Position vector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Position (J2000 Earth-centered)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 8) {
                            CoordLabel(axis: "X", value: data.positionKm.x)
                            CoordLabel(axis: "Y", value: data.positionKm.y)
                            CoordLabel(axis: "Z", value: data.positionKm.z)
                        }
                    }
                }

                if let lastUpdated = viewModel.lastUpdated {
                    HStack {
                        Text("Updated \(lastUpdated, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ProgressView("Fetching Artemis position...")
                    .padding()
            }

            Divider()

            // Actions
            HStack {
                Button(action: onToggleOverlay) {
                    Label("Floating Overlay", systemImage: "macwindow.on.rectangle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(action: { viewModel.fetchData() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Label("Quit", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .frame(width: 340)
    }
}

struct StatRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
        }
    }
}

struct CoordLabel: View {
    let axis: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(axis)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text(String(format: "%.0f", value))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
