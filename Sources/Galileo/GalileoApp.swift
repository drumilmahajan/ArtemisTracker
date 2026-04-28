import SwiftUI
import AppKit

@main
struct GalileoApp: App {
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
    var eventWindow: NSWindow?
    var viewModel = GalileoViewModel()
    private var sceneWindowObserver: Any?
    private var eventWindowObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: 28)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Galileo")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                viewModel: viewModel,
                onOpen3D: { [weak self] in self?.open3DWindow() },
                onOpenEvent: { [weak self] event in self?.openEventDetail(event) }
            )
        )

        viewModel.startTracking()
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopTracking()
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
        let missionName = viewModel.watchedMission?.name ?? "Mission"
        window.title = "\(missionName) - 3D Trajectory"
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        sceneWindow = window

        if let old = sceneWindowObserver {
            NotificationCenter.default.removeObserver(old)
        }
        sceneWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.sceneWindow = nil
            self?.sceneWindowObserver = nil
            if self?.eventWindow == nil {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    // MARK: - Event Detail Window

    func openEventDetail(_ event: SpaceEvent) {
        popover.performClose(nil)

        eventWindow?.close()

        let hostingView = NSHostingView(
            rootView: EventDetailView(event: event, viewModel: viewModel)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = event.missionName ?? event.name
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        eventWindow = window

        if let old = eventWindowObserver {
            NotificationCenter.default.removeObserver(old)
        }
        eventWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.eventWindow = nil
            self?.eventWindowObserver = nil
            if self?.sceneWindow == nil {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

// MARK: - Full 3D Window

struct SceneWindowView: View {
    @ObservedObject var viewModel: GalileoViewModel
    @State private var resetTrigger = 0

    private var mission: TrackableMission? { viewModel.watchedMission }

    var body: some View {
        HStack(spacing: 0) {
            TrajectorySceneView(viewModel: viewModel, resetTrigger: resetTrigger)
                .frame(minWidth: 500)

            // Right sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Mission header
                    VStack(alignment: .leading, spacing: 4) {
                        Text((mission?.name ?? "Unknown").uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)

                        if let m = mission {
                            Text(m.description)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    if let data = viewModel.latestData {
                        // Unit toggle
                        HStack {
                            Spacer()
                            Picker("", selection: Binding(
                                get: { viewModel.units },
                                set: { viewModel.unitSystem = $0.rawValue }
                            )) {
                                Text("km").tag(UnitSystem.metric)
                                Text("mi").tag(UnitSystem.imperial)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                            Spacer()
                        }

                        // Telemetry
                        let centerLabel = mission?.centerBody == .sun ? "FROM SUN" : "FROM EARTH"
                        Group {
                            StatBlock(label: centerLabel, value: viewModel.units.formatDistance(data.distanceFromCenterKm), color: .blue)
                            if mission?.showMoon == true {
                                StatBlock(label: "FROM MOON", value: viewModel.units.formatDistance(data.distanceFromMoonKm), color: .gray)
                            }
                            StatBlock(label: "SPEED", value: viewModel.units.formatSpeed(data.speedKmS), color: .orange)
                            StatBlock(label: "SIGNAL DELAY", value: data.signalDelayFormatted, color: .cyan)
                            StatBlock(label: "RANGE RATE", value: viewModel.units.formatVelocity(data.rangeRateKmS),
                                      color: data.rangeRateKmS > 0 ? .red : .green)
                        }

                        Divider()

                        // Position
                        VStack(alignment: .leading, spacing: 4) {
                            Text("POSITION (\(viewModel.units.distanceUnit))")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Text("X: \(viewModel.units.formatPosition(data.positionKm.x))")
                                .font(.system(size: 10, design: .monospaced))
                            Text("Y: \(viewModel.units.formatPosition(data.positionKm.y))")
                                .font(.system(size: 10, design: .monospaced))
                            Text("Z: \(viewModel.units.formatPosition(data.positionKm.z))")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }

                    Divider()

                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("Live")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .frame(width: 220)
            .background(.ultraThinMaterial)
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
