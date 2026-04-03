import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: ArtemisViewModel
    var onToggleOverlay: () -> Void
    var onOpen3D: () -> Void

    var body: some View {
        VStack(spacing: 12) {
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

                // Progress bar Earth -> Moon
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

                // Stats
                VStack(spacing: 10) {
                    StatRow(icon: "globe.americas.fill", iconColor: .blue,
                            label: "From Earth", value: data.distanceFromEarthFormatted)
                    StatRow(icon: "moon.fill", iconColor: .gray,
                            label: "From Moon", value: data.distanceFromMoonFormatted)
                    StatRow(icon: "gauge.with.needle.fill", iconColor: .orange,
                            label: "Speed", value: data.speedFormatted)
                }

                // Mini 3D preview
                TrajectorySceneView(viewModel: viewModel)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )

                if let lastFetch = viewModel.lastAPIFetch {
                    HStack {
                        Text("API: \(lastFetch, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Live interpolation")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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
                    Label("Overlay", systemImage: "macwindow.on.rectangle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(action: onOpen3D) {
                    Label("3D View", systemImage: "cube.fill")
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
