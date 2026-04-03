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

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Artemis Tracker")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 560)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                viewModel: viewModel,
                onToggleOverlay: { [weak self] in self?.toggleFloatingWindow() },
                onOpen3D: { [weak self] in self?.open3DWindow() }
            )
        )

        viewModel.startTracking()

        // Update menu bar title
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, let data = self.viewModel.latestData else { return }
                self.statusItem.button?.title = " \(data.distanceFromEarthFormatted)"
            }
        }
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

    var body: some View {
        HStack(spacing: 0) {
            // 3D Scene
            TrajectorySceneView(viewModel: viewModel)
                .frame(minWidth: 400)

            // Stats sidebar
            VStack(alignment: .leading, spacing: 16) {
                Text("MISSION DATA")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                if let data = viewModel.latestData {
                    Group {
                        StatBlock(label: "FROM EARTH", value: data.distanceFromEarthFormatted, color: .blue)
                        StatBlock(label: "FROM MOON", value: data.distanceFromMoonFormatted, color: .gray)
                        StatBlock(label: "SPEED", value: data.speedFormatted, color: .orange)
                        StatBlock(label: "PHASE", value: data.missionPhase, color: .green)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("POSITION (km)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text("X: \(String(format: "%.1f", data.positionKm.x))")
                            .font(.system(size: 11, design: .monospaced))
                        Text("Y: \(String(format: "%.1f", data.positionKm.y))")
                            .font(.system(size: 11, design: .monospaced))
                        Text("Z: \(String(format: "%.1f", data.positionKm.z))")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("Live")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            .padding()
            .frame(width: 180)
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
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
        }
    }
}
