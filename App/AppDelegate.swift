import AppKit
import os

private let log = Logger(subsystem: "dev.slkiser.nufi", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        verifyAppGroup()
        NSApp.mainMenu = MainMenu.build()
        applyAppearance()
        NotificationCenter.default.addObserver(
            forName: NufiNotification.appearanceChanged, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in self.applyAppearance() }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NufiNotification.openPreferences,
            object: nil,
            queue: .main
        ) { _ in
            SettingsStore.appGroupStore()?.pendingOpenPreferences = false
            Task { @MainActor in Windows.shared.showSettings() }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NufiNotification.renameRequested,
            object: nil,
            queue: .main
        ) { _ in
            // The sandbox strips userInfo from distributed notifications, so
            // the path travels through the shared store instead.
            Task { @MainActor in Self.consumePendingRename() }
        }

        // The extension latches these before launching us; the distributed
        // notifications above are missed on a cold launch.
        Self.consumePendingRename()
        let store = SettingsStore.appGroupStore()
        if let store, store.pendingOpenPreferences {
            store.pendingOpenPreferences = false
            Windows.shared.showSettings()
        } else if !SetupStatus.current().isComplete {
            Windows.shared.showOnboarding()
        }
    }

    /// Launching Nufi while it is already running: finish setup if needed,
    /// otherwise open Settings. Accessory apps have no window to reopen.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if SetupStatus.current().isComplete {
            Windows.shared.showSettings()
        } else {
            Windows.shared.showOnboarding()
        }
        return false
    }

    /// Menu bar item and Dock icon follow the settings. Dock on means a
    /// regular app with a main menu; Dock off keeps Nufi an accessory.
    @MainActor
    private func applyAppearance() {
        let store = SettingsStore.appGroupStore()
        StatusItemController.shared.applySettings()
        let wantsDock = store?.showDockIcon ?? false
        let policy: NSApplication.ActivationPolicy = wantsDock ? .regular : .accessory
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
            if wantsDock { NSApp.activate(ignoringOtherApps: true) }
        }
    }

    @MainActor
    private static func consumePendingRename() {
        guard let store = SettingsStore.appGroupStore(), let path = store.pendingRenamePath else {
            log.info("rename requested but no pending path")
            return
        }
        store.pendingRenamePath = nil
        guard FileManager.default.fileExists(atPath: path) else {
            log.error("rename target missing: \(path, privacy: .public)")
            return
        }
        log.info("rename \(path, privacy: .public)")
        FinderInlineRename.beginRenaming(fileAt: URL(fileURLWithPath: path))
    }

    @MainActor @objc func showSettings() {
        Windows.shared.showSettings(page: nil)
    }

    @MainActor @objc func showAbout() {
        Windows.shared.showSettings(page: .about)
    }

    private func verifyAppGroup() {
        if SettingsStore.appGroupStore() == nil {
            let alert = NSAlert()
            alert.messageText = "Nufi is misconfigured"
            alert.informativeText = """
                Nufi can't reach its shared settings store. \
                This usually means the app needs to be reinstalled. \
                Settings won't sync between the app and the Finder extension until this is fixed.
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
