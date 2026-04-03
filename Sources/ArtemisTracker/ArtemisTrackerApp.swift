import SwiftUI
import AppKit

@main
struct ArtemisTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var sceneWindow: NSWindow?
    var viewModel = ArtemisViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: 28)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Artemis Tracker")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                viewModel: viewModel,
                onOpen3D: { [weak self] in self?.open3DWindow() }
            )
        )

        viewModel.startTracking()
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    // MARK: - 3D Window

    func open3DWindow() {
        if let window = sceneWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingView = NSHostingView(
            rootView: SceneWindowView(viewModel: viewModel)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = "Artemis II - 3D Trajectory"
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        sceneWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.sceneWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - Full 3D Window

struct SceneWindowView: View {
    @ObservedObject var viewModel: ArtemisViewModel
    @State private var resetTrigger = 0

    var body: some View {
        HStack(spacing: 0) {
            TrajectorySceneView(viewModel: viewModel, resetTrigger: resetTrigger)
                .frame(minWidth: 500)

            // Right sidebar with all mission data
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // MET + Progress
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ARTEMIS II")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(viewModel.met)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.quaternary).frame(height: 4)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(colors: [.blue, .cyan, .green],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(3, geo.size.width * viewModel.missionProgress), height: 4)
                            }
                        }
                        .frame(height: 4)
                        Text(String(format: "Mission %.1f%% complete", viewModel.missionProgress * 100))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    Divider()

                    if let data = viewModel.latestData {
                        // Telemetry
                        Group {
                            StatBlock(label: "FROM EARTH", value: data.distanceFromEarthFormatted, color: .blue)
                            StatBlock(label: "FROM MOON", value: data.distanceFromMoonFormatted, color: .gray)
                            StatBlock(label: "SPEED", value: MissionData.speedContext(kmPerSec: data.speedKmS), color: .orange)
                            StatBlock(label: "SIGNAL DELAY", value: data.signalDelayFormatted, color: .cyan)
                            StatBlock(label: "RANGE RATE", value: String(format: "%+.2f km/s", data.rangeRateKmS),
                                      color: data.rangeRateKmS > 0 ? .red : .green)
                            StatBlock(label: "PHASE", value: data.missionPhase, color: .green)
                        }

                        Divider()

                        // Position
                        VStack(alignment: .leading, spacing: 4) {
                            Text("POSITION (km)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Text("X: \(String(format: "%.1f", data.positionKm.x))")
                                .font(.system(size: 10, design: .monospaced))
                            Text("Y: \(String(format: "%.1f", data.positionKm.y))")
                                .font(.system(size: 10, design: .monospaced))
                            Text("Z: \(String(format: "%.1f", data.positionKm.z))")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundStyle(.secondary)

                        Divider()

                        // Crew
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CREW")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            ForEach(MissionData.crew, id: \.name) { member in
                                HStack(spacing: 6) {
                                    Text(member.flag).font(.system(size: 12))
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(member.name)
                                            .font(.system(size: 10, weight: .medium))
                                        Text("\(member.role) · \(member.agency)")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        Divider()

                        // Timeline
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TIMELINE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.tertiary)

                            ForEach(MissionData.timeline, id: \.title) { event in
                                HStack(spacing: 6) {
                                    Image(systemName: event.isPast ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 9))
                                        .foregroundStyle(event.isPast ? .green : .secondary)
                                    Text(event.title)
                                        .font(.system(size: 9, weight: event.isPast ? .regular : .medium))
                                        .foregroundStyle(event.isPast ? .secondary : .primary)
                                }
                            }
                        }
                    } else {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }

                    Divider()

                    // Legend
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LEGEND")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        LegendRow(color: .green, label: "Planned trajectory")
                        LegendRow(color: .gray, label: "Moon orbit")
                    }

                    // Reset + Live
                    HStack {
                        Button(action: { resetTrigger += 1 }) {
                            Label("Reset View", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("Live")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .frame(width: 220)
            .background(.ultraThinMaterial)
        }
    }
}

struct LegendRow: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 14, height: 3)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

struct StatBlock: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.8))
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
    }
}
