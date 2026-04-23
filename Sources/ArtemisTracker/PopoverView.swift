import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: ArtemisViewModel
    var onOpen3D: () -> Void
    var onOpenEvent: (SpaceEvent) -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let mission = viewModel.watchedMission {
                if mission.id == TrackableMission.artemisII.id {
                    artemisSection
                } else {
                    missionSection(mission)
                }
            } else if let event = viewModel.watchedEvent {
                watchedEventSection(event)
            } else {
                // Nothing selected — show Artemis by default
                artemisSection
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
        .frame(width: 320)
    }

    // MARK: - Artemis II Section

    @ViewBuilder
    private var artemisSection: some View {
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
            HStack {
                Label(data.missionPhase, systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            VStack(spacing: 6) {
                TelemetryRow(icon: "globe.americas.fill", iconColor: .blue,
                             label: "From Earth", value: viewModel.units.formatDistance(data.distanceFromEarthKm))
                TelemetryRow(icon: "moon.fill", iconColor: .gray,
                             label: "From Moon", value: viewModel.units.formatDistance(data.distanceFromMoonKm))
                TelemetryRow(icon: "gauge.with.needle.fill", iconColor: .orange,
                             label: "Speed", value: viewModel.units.formatSpeed(data.speedKmS))
            }

            Divider()

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
                             value: viewModel.units.formatDistance(data.distanceFromEarthKm))
                TelemetryRow(icon: "gauge.with.needle.fill", iconColor: .orange,
                             label: "Speed", value: viewModel.units.formatSpeed(data.speedKmS))
            }

            HStack {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("Live")
                    .font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text(mission.description)
                    .font(.caption2).foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        } else if viewModel.isLoading {
            ProgressView("Connecting to JPL Horizons...")
                .padding()
        }
    }

    // MARK: - Watched Event Section

    @ViewBuilder
    private func watchedEventSection(_ event: SpaceEvent) -> some View {
        // Header
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

        // Countdown
        VStack(spacing: 4) {
            Text("LAUNCH COUNTDOWN")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(event.countdownFormatted)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(event.timeUntilLaunch < 3600 ? .orange : .primary)
        }

        // Status
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
