import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: ArtemisViewModel
    var onOpen3D: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Header + MET
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Orion · Artemis II")
                        .font(.headline)
                    Text(viewModel.met)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Text(String(format: "%.1f%%", viewModel.missionProgress * 100))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            if let data = viewModel.latestData {
                // Phase
                HStack {
                    Label(data.missionPhase, systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // Core telemetry
                VStack(spacing: 6) {
                    TelemetryRow(icon: "globe.americas.fill", iconColor: .blue,
                                 label: "From Earth", value: viewModel.units.formatDistance(data.distanceFromEarthKm))
                    TelemetryRow(icon: "moon.fill", iconColor: .gray,
                                 label: "From Moon", value: viewModel.units.formatDistance(data.distanceFromMoonKm))
                    TelemetryRow(icon: "gauge.with.needle.fill", iconColor: .orange,
                                 label: "Speed", value: viewModel.units.formatSpeed(data.speedKmS))
                }

                Divider()

                // Next event
                if let next = MissionData.nextEvent() {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.cyan)
                            .font(.system(size: 12))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("NEXT: \(next.event.title)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            Text(next.event.detail)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }

                // Status
                HStack {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("Live")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("Signal: \(data.signalDelayFormatted)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle).foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ProgressView("Connecting to NASA JPL Horizons...")
                    .padding()
            }

            Divider()

            // Actions
            HStack {
                Button(action: onOpen3D) {
                    Label("3D View", systemImage: "cube.fill").font(.caption)
                }.buttonStyle(.bordered)

                Spacer()

                Picker("", selection: Binding(
                    get: { viewModel.units },
                    set: { viewModel.unitSystem = $0.rawValue }
                )) {
                    Text("km").tag(UnitSystem.metric)
                    Text("mi").tag(UnitSystem.imperial)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Label("Quit", systemImage: "xmark.circle").font(.caption)
                }.buttonStyle(.bordered).tint(.red)
            }
        }
        .padding()
        .frame(width: 320)
    }
}

struct TelemetryRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 18)
            Text(label)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
    }
}
