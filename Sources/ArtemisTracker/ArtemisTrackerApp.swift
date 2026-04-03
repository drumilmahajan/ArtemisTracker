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
    var floatingWindow: NSWindow?
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
        popover.contentSize = NSSize(width: 360, height: 580)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                viewModel: viewModel,
                onToggleOverlay: { [weak self] in self?.toggleFloatingWindow() },
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

    // MARK: - Floating Overlay

    func toggleFloatingWindow() {
        if let window = floatingWindow {
            window.close()
            floatingWindow = nil
        } else {
            createFloatingWindow()
        }
    }

    func createFloatingWindow() {
        let hostingView = NSHostingView(
            rootView: FloatingOverlayView(viewModel: viewModel, onClose: { [weak self] in
                self?.floatingWindow?.close()
                self?.floatingWindow = nil
            })
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 55),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.hasShadow = true
        window.isOpaque = false
        window.isReleasedWhenClosed = false

        // Round corners
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 10
        window.contentView?.layer?.masksToBounds = true

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 210
            let y = screenFrame.maxY - 65
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.orderFrontRegardless()
        floatingWindow = window
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
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = "Artemis II - 3D Trajectory"
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Need to show in dock when 3D window is open
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        sceneWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.sceneWindow = nil
            // Hide from dock again if no other windows
            if self?.floatingWindow == nil {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

/// Full 3D window view with stats sidebar
struct SceneWindowView: View {
    @ObservedObject var viewModel: ArtemisViewModel
    @State private var resetTrigger = 0

    var body: some View {
        HStack(spacing: 0) {
            // 3D Scene
            TrajectorySceneView(viewModel: viewModel, resetTrigger: resetTrigger)
                .frame(minWidth: 400)

            // Stats sidebar
            VStack(alignment: .leading, spacing: 12) {
                // MET
                VStack(alignment: .leading, spacing: 2) {
                    Text("ARTEMIS II")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(viewModel.met)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                }

                if let data = viewModel.latestData {
                    Group {
                        StatBlock(label: "FROM EARTH", value: data.distanceFromEarthFormatted, color: .blue)
                        StatBlock(label: "FROM MOON", value: data.distanceFromMoonFormatted, color: .gray)
                        StatBlock(label: "SPEED", value: MissionData.speedContext(kmPerSec: data.speedKmS), color: .orange)
                        StatBlock(label: "SIGNAL DELAY", value: data.signalDelayFormatted, color: .cyan)
                        StatBlock(label: "PHASE", value: data.missionPhase, color: .green)
                    }

                    Spacer()

                    // Legend
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LEGEND")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        LegendRow(color: .green, label: "Planned trajectory")
                        LegendRow(color: .gray, label: "Moon orbit")
                    }

                    Divider()

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
                } else {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            .padding()
            .frame(width: 190)
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
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
        }
    }
}
