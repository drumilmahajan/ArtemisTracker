import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: ArtemisViewModel
    var onToggleOverlay: () -> Void
    var onOpen3D: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header + MET
                headerSection

                Divider()

                if let data = viewModel.latestData {
                    // Mission progress
                    progressSection(data: data)

                    // Key telemetry
                    telemetrySection(data: data)

                    Divider()

                    // Signal & Speed
                    signalSpeedSection(data: data)

                    Divider()

                    // Crew
                    crewSection

                    Divider()

                    // Timeline
                    timelineSection

                    Divider()

                    // API status
                    statusRow
                } else if let error = viewModel.errorMessage {
                    errorSection(error: error)
                } else {
                    ProgressView("Connecting to NASA JPL Horizons...")
                        .padding()
                }

                // Actions
                actionButtons
            }
            .padding()
        }
        .frame(width: 360, height: 580)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text("Artemis II")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            HStack {
                Text(viewModel.met)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%.1f%%", viewModel.missionProgress * 100))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Progress

    private func progressSection(data: ArtemisData) -> some View {
        VStack(spacing: 6) {
            HStack {
                Label(data.missionPhase, systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Mission progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            colors: [.blue, .cyan, .green],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: max(4, geo.size.width * viewModel.missionProgress), height: 6)
                }
            }
            .frame(height: 6)

            // Earth -> Moon bar
            HStack(spacing: 4) {
                Image(systemName: "globe.americas.fill")
                    .foregroundStyle(.blue).font(.system(size: 10))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary).frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.cyan.opacity(0.6)).frame(width: max(3, geo.size.width * data.progressToMoon), height: 4)
                        Image(systemName: "airplane")
                            .font(.system(size: 8))
                            .rotationEffect(.degrees(-45))
                            .offset(x: max(0, geo.size.width * data.progressToMoon - 6), y: -6)
                    }
                }
                .frame(height: 14)
                Image(systemName: "moon.fill")
                    .foregroundStyle(.gray).font(.system(size: 10))
            }
        }
    }

    // MARK: - Telemetry

    private func telemetrySection(data: ArtemisData) -> some View {
        VStack(spacing: 8) {
            TelemetryRow(icon: "globe.americas.fill", iconColor: .blue,
                         label: "From Earth", value: data.distanceFromEarthFormatted)
            TelemetryRow(icon: "moon.fill", iconColor: .gray,
                         label: "From Moon", value: data.distanceFromMoonFormatted)
            TelemetryRow(icon: "gauge.with.needle.fill", iconColor: .orange,
                         label: "Speed", value: data.speedFormatted)
        }
    }

    // MARK: - Signal & Speed Context

    private func signalSpeedSection(data: ArtemisData) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SIGNAL DELAY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.7))
                Text(data.signalDelayFormatted)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }

            Divider().frame(height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("SPEED")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange.opacity(0.7))
                Text(MissionData.speedContext(kmPerSec: data.speedKmS))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }

            Divider().frame(height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("RANGE RATE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(data.rangeRateKmS > 0 ? .red.opacity(0.7) : .green.opacity(0.7))
                Text(String(format: "%+.2f km/s", data.rangeRateKmS))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
        }
    }

    // MARK: - Crew

    private var crewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CREW")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(MissionData.crew, id: \.name) { member in
                    HStack(spacing: 6) {
                        Text(member.flag)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(member.name)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                            Text(member.role)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TIMELINE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                if let next = MissionData.nextEvent() {
                    Text("Next: \(next.event.title)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
            }

            // Show last 2 completed + next 3 upcoming
            let events = relevantEvents()
            ForEach(events, id: \.title) { event in
                HStack(spacing: 8) {
                    Image(systemName: event.isPast ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10))
                        .foregroundStyle(event.isPast ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title)
                            .font(.system(size: 10, weight: event.isPast ? .regular : .medium))
                            .foregroundStyle(event.isPast ? .secondary : .primary)
                        Text(event.detail)
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
        }
    }

    private func relevantEvents() -> [MissionData.MissionEvent] {
        let all = MissionData.timeline
        let pastEvents = all.filter { $0.isPast }
        let futureEvents = all.filter { !$0.isPast }
        let showPast = pastEvents.suffix(2)
        let showFuture = futureEvents.prefix(3)
        return Array(showPast) + Array(showFuture)
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack {
            if let lastFetch = viewModel.lastAPIFetch {
                Text("API: \(lastFetch, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Circle().fill(.green).frame(width: 6, height: 6)
            Text("Live")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Error

    private func errorSection(error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle).foregroundStyle(.yellow)
            Text(error)
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack {
            Button(action: onToggleOverlay) {
                Label("Overlay", systemImage: "macwindow.on.rectangle").font(.caption)
            }.buttonStyle(.bordered)

            Button(action: onOpen3D) {
                Label("3D View", systemImage: "cube.fill").font(.caption)
            }.buttonStyle(.bordered)

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit", systemImage: "xmark.circle").font(.caption)
            }.buttonStyle(.bordered).tint(.red)
        }
    }
}

// MARK: - Telemetry Row

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
                .font(.system(size: 13))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
        }
    }
}
