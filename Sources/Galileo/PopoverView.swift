import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: GalileoViewModel
    var onOpen3D: () -> Void
    var onOpenEvent: (SpaceEvent) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Watched mission/event header
                if let mission = viewModel.watchedMission {
                    missionSection(mission)
                } else if let event = viewModel.watchedEvent {
                    watchedEventSection(event)
                }

                Divider()

                // Active missions
                VStack(alignment: .leading, spacing: 6) {
                    Text("ACTIVE MISSIONS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    ForEach(TrackableMission.allMissions) { mission in
                        Button(action: { viewModel.watchMission(mission) }) {
                            HStack(spacing: 6) {
                                Image(systemName: missionIcon(mission))
                                    .font(.system(size: 9))
                                    .foregroundStyle(missionColor(mission))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(mission.name)
                                        .font(.system(size: 10, weight: .medium))
                                        .lineLimit(1)
                                    Text(mission.agency)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if viewModel.watchedEventId == mission.id {
                                    Image(systemName: "eye.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // In Space Now (live from LL2)
                if !viewModel.spacecraftInOrbit.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("IN SPACE NOW")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        ForEach(Array(viewModel.spacecraftInOrbit.prefix(5))) { craft in
                            HStack(spacing: 6) {
                                Image(systemName: "airplane")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.cyan)
                                    .rotationEffect(.degrees(-45))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(craft.name)
                                        .font(.system(size: 10, weight: .medium))
                                        .lineLimit(1)
                                    Text("\(craft.agencyName) · \(craft.configName)")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if !craft.timeInSpaceFormatted.isEmpty {
                                    Text(craft.timeInSpaceFormatted)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                }

                Divider()

                // Upcoming launches
                if !viewModel.upcomingEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("UPCOMING LAUNCHES")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        ForEach(viewModel.upcomingEvents.prefix(5)) { event in
                            Button(action: { onOpenEvent(event) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(event.timeUntilLaunch < 86400 ? .orange : .secondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(event.missionName ?? event.name)
                                            .font(.system(size: 10, weight: .medium))
                                            .lineLimit(1)
                                        Text("\(event.provider) · \(event.rocketName)")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if viewModel.watchedEventId == event.id {
                                        Image(systemName: "eye.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.green)
                                    }
                                    Text(event.countdownFormatted)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(event.timeUntilLaunch < 3600 ? Color.orange : Color.gray)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()
                }

                // Actions
                HStack {
                    if viewModel.watchedMission != nil {
                        Button(action: onOpen3D) {
                            Label("3D View", systemImage: "cube.fill").font(.caption)
                        }.buttonStyle(.bordered)
                    }

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
        }
        .frame(width: 320)
        .frame(maxHeight: 600)
    }

    // MARK: - Generic Mission Section

    @ViewBuilder
    private func missionSection(_ mission: TrackableMission) -> some View {
        HStack {
            Image(systemName: missionIcon(mission))
                .font(.title2)
                .foregroundStyle(missionColor(mission))
            VStack(alignment: .leading, spacing: 2) {
                Text(mission.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(mission.spacecraft) · \(mission.agency)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "eye.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        }

        Divider()

        if let data = viewModel.latestData {
            VStack(spacing: 6) {
                TelemetryRow(icon: "globe.americas.fill", iconColor: .blue,
                             label: "From \(mission.centerBody == .earth ? "Earth" : "Sun")",
                             value: viewModel.units.formatDistance(data.distanceFromCenterKm))
                if mission.showMoon {
                    TelemetryRow(icon: "moon.fill", iconColor: .gray,
                                 label: "From Moon", value: viewModel.units.formatDistance(data.distanceFromMoonKm))
                }
                TelemetryRow(icon: "gauge.with.needle.fill", iconColor: .orange,
                             label: "Speed", value: viewModel.units.formatSpeed(data.speedKmS))
            }

            HStack {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("Live")
                    .font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("Signal: \(data.signalDelayFormatted)")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        } else if viewModel.isLoading {
            ProgressView("Connecting to JPL Horizons...")
                .padding()
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle).foregroundStyle(.yellow)
                Text(error)
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    // MARK: - Watched Event Section

    @ViewBuilder
    private func watchedEventSection(_ event: SpaceEvent) -> some View {
        HStack {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.missionName ?? event.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(event.provider) · \(event.rocketName)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "eye.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        }

        Divider()

        VStack(spacing: 4) {
            Text("LAUNCH COUNTDOWN")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(event.countdownFormatted)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(event.timeUntilLaunch < 3600 ? .orange : .primary)
        }

        HStack {
            Text(event.status.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor(for: event).opacity(0.2))
                .foregroundStyle(statusColor(for: event))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Spacer()
            Button(action: { onOpenEvent(event) }) {
                Text("Details")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
    }

    private func statusColor(for event: SpaceEvent) -> Color {
        let s = event.status.lowercased()
        if s.contains("go") { return .green }
        if s.contains("tbd") || s.contains("tbc") { return .yellow }
        if s.contains("hold") || s.contains("failure") { return .red }
        return .blue
    }

    private func missionIcon(_ mission: TrackableMission) -> String {
        switch mission.orbitType {
        case .lowEarthOrbit: return "globe.americas.fill"
        case .lunarTransit: return "moon.stars.fill"
        case .lagrangePoint: return "scope"
        case .interplanetary: return "star.fill"
        }
    }

    private func missionColor(_ mission: TrackableMission) -> Color {
        switch mission.orbitType {
        case .lowEarthOrbit: return .blue
        case .lunarTransit: return .yellow
        case .lagrangePoint: return .purple
        case .interplanetary: return .cyan
        }
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
