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
    var viewModel = ArtemisViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Artemis Tracker")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel, onToggleOverlay: { [weak self] in
                self?.toggleFloatingWindow()
            })
        )

        // Start fetching data
        viewModel.startTracking()

        // Update menu bar title with distance
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
                viewModel.fetchData()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    func toggleFloatingWindow() {
        if let window = floatingWindow {
            window.close()
            floatingWindow = nil
        } else {
            createFloatingWindow()
        }
    }

    func createFloatingWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 70),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        let hostingView = NSHostingView(
            rootView: FloatingOverlayView(viewModel: viewModel, onClose: { [weak self] in
                self?.closeFloatingWindow()
            })
        )

        window.contentView = hostingView
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.hasShadow = true
        window.isReleasedWhenClosed = false

        // Position at top center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 200
            let y = screenFrame.maxY - 80
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.orderFrontRegardless()
        floatingWindow = window
    }

    func closeFloatingWindow() {
        floatingWindow?.close()
        floatingWindow = nil
    }
}
