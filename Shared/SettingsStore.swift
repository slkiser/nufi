import Foundation

final class SettingsStore {
    // macOS requires app-group IDs to be Team-ID-prefixed; an iOS-style
    // "group." identifier makes containermanagerd gate the shared container
    // behind TCC (host-app prompt + extension rejection). Team ID: 28W383DD2Q.
    static let appGroupID = NufiIdentity.appGroupID

    private enum Key {
        static let fileTypes = "fileTypes"
        static let submenu = "useRightClickSubmenu"
        static let selectedFolder = "createInSelectedFolder"
        static let schema = "schemaVersion"
        static let pendingOpenPreferences = "pendingOpenPreferences"
        static let pendingRenamePath = "pendingRenamePath"
        static let menuBarItem = "showMenuBarItem"
        static let dockIcon = "showDockIcon"
    }

    private static let currentSchema = 2

    private let defaults: UserDefaults

    /// Production callers pass `UserDefaults(suiteName: SettingsStore.appGroupID)!`.
    /// Tests pass an isolated suite.
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Convenience factory for production use. Returns nil if the App Group
    /// suite is not entitled — caller decides how to surface the error.
    static func appGroupStore() -> SettingsStore? {
        guard let suite = UserDefaults(suiteName: appGroupID) else { return nil }
        return SettingsStore(defaults: suite)
    }

    var fileTypes: [FileTypeEntry] {
        get {
            if let data = defaults.data(forKey: Key.fileTypes),
               let decoded = try? JSONDecoder().decode([FileTypeEntry].self, from: data) {
                return migrateIfNeeded(decoded)
            }
            // First read or corrupted JSON — seed and persist.
            let seeded = SeedPresets.builtIns
            persist(seeded)
            defaults.set(Self.currentSchema, forKey: Key.schema)
            return seeded
        }
        set {
            persist(newValue)
        }
    }

    var enabledTypes: [FileTypeEntry] {
        fileTypes.filter { $0.enabled }
    }

    /// Defaults on so blank types sit under "New File" beside "Paste as New File".
    var useRightClickSubmenu: Bool {
        get {
            if defaults.object(forKey: Key.submenu) == nil { return true }
            return defaults.bool(forKey: Key.submenu)
        }
        set { defaults.set(newValue, forKey: Key.submenu) }
    }

    /// When on, a folder right-clicked in its parent also gets Nufi's actions.
    /// Background of an open folder remains the default target.
    var createInSelectedFolder: Bool {
        get { defaults.bool(forKey: Key.selectedFolder) }
        set { defaults.set(newValue, forKey: Key.selectedFolder) }
    }

    /// Latch flipped by the extension before `NSWorkspace.shared.open(host)`.
    /// AppDelegate consumes-and-clears on launch so the host app shows
    /// Preferences instead of the welcome window when launched via the
    /// extension's "Customize…" / empty-list-recovery row. The distributed
    /// notification alone can't carry this intent across launch because the
    /// observer registers after the notification has already been posted.
    /// Where the app shows itself. At least one stays on; the UI enforces it.
    var showMenuBarItem: Bool {
        get {
            if defaults.object(forKey: Key.menuBarItem) == nil { return true }
            return defaults.bool(forKey: Key.menuBarItem)
        }
        set { defaults.set(newValue, forKey: Key.menuBarItem) }
    }

    var showDockIcon: Bool {
        get { defaults.bool(forKey: Key.dockIcon) }
        set { defaults.set(newValue, forKey: Key.dockIcon) }
    }

    /// Same handoff for rename: set by the extension before launching the
    /// app when it is not running. Cleared once consumed.
    var pendingRenamePath: String? {
        get { defaults.string(forKey: Key.pendingRenamePath) }
        set { defaults.set(newValue, forKey: Key.pendingRenamePath) }
    }

    var pendingOpenPreferences: Bool {
        get { defaults.bool(forKey: Key.pendingOpenPreferences) }
        set { defaults.set(newValue, forKey: Key.pendingOpenPreferences) }
    }

    /// Schema 1 -> 2: custom types were created with a hardcoded displayName
    /// of "New file" and no UI to change it (issue #2). Blank those out so the
    /// menu falls back to the ext-derived label. Runs once, keyed on
    /// schemaVersion, so a label the user later types as "New file" sticks.
    private func migrateIfNeeded(_ types: [FileTypeEntry]) -> [FileTypeEntry] {
        guard defaults.integer(forKey: Key.schema) < 2 else { return types }
        var migrated = types
        for i in migrated.indices
        where !migrated[i].isBuiltIn && migrated[i].displayName == "New file" {
            migrated[i].displayName = ""
        }
        if migrated != types { persist(migrated) }
        defaults.set(Self.currentSchema, forKey: Key.schema)
        return migrated
    }

    private func persist(_ types: [FileTypeEntry]) {
        guard let data = try? JSONEncoder().encode(types) else { return }
        defaults.set(data, forKey: Key.fileTypes)
    }
}
