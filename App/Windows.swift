import AppKit
import SwiftUI

/// One window each for onboarding and Settings, created on demand and kept
/// alive while closed so they reopen in the same place.
@MainActor
final class Windows {
    static let shared = Windows()

    private var onboarding: NSWindow?
    private var settings: NSWindow?

    func showOnboarding() {
        if onboarding == nil {
            onboarding = make(title: "Welcome to Nufi", view: OnboardingView(),
                              size: nil, resizable: false)
            // The heading is in the content; keep the title for the Dock and
            // Mission Control only.
            onboarding?.titleVisibility = .hidden
        }
        present(onboarding!)
    }

    func closeOnboarding() {
        onboarding?.close()
    }

    private let settingsNavigation = SettingsNavigation()

    func showSettings(page: SettingsPage? = nil) {
        if let page { settingsNavigation.page = page }
        if settings == nil {
            let window = make(title: "Nufi Settings",
                              view: SettingsShellView(navigation: settingsNavigation),
                              size: NSSize(width: 720, height: 520), resizable: true)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.minSize = NSSize(width: 640, height: 440)
            settings = window
        }
        present(settings!)
    }

    /// A nil size lets the window fit the SwiftUI content.
    private func make<V: View>(title: String, view: V, size: NSSize?, resizable: Bool) -> NSWindow {
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = title
        window.styleMask = resizable
            ? [.titled, .closable, .miniaturizable, .resizable]
            : [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = !resizable
        if let size { window.setContentSize(size) }
        window.center()
        window.isReleasedWhenClosed = false
        return window
    }

    private func present(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
