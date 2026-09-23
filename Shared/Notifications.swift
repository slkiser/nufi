import Foundation

enum NufiNotification {
    static let toolbarOrMenuUsed =
        Notification.Name("dev.slkiser.nufi.toolbarOrMenuUsed")
    static let openPreferences =
        Notification.Name("dev.slkiser.nufi.openPreferences")
    /// Extension -> app: start Finder's inline rename for the path stored in
    /// SettingsStore.pendingRenamePath. The sandbox drops userInfo, so the
    /// notification is only a nudge. Only the app holds Accessibility and
    /// Automation.
    static let renameRequested =
        Notification.Name("dev.slkiser.nufi.renameRequested")
    /// In-process: appearance settings changed (menu bar item, Dock icon).
    static let appearanceChanged =
        Notification.Name("dev.slkiser.nufi.appearanceChanged")
}
