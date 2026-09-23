import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
    @Published var fileTypes: [FileTypeEntry]
    @Published var useRightClickSubmenu: Bool {
        didSet { store?.useRightClickSubmenu = useRightClickSubmenu }
    }
    @Published var createInSelectedFolder: Bool {
        didSet { store?.createInSelectedFolder = createInSelectedFolder }
    }
    @Published var showMenuBarItem: Bool {
        didSet { if showMenuBarItem != oldValue { appearanceChanged(menuBar: true) } }
    }
    @Published var showDockIcon: Bool {
        didSet { if showDockIcon != oldValue { appearanceChanged(menuBar: false) } }
    }
    @Published var launchAtLogin: Bool {
        didSet { if launchAtLogin != oldValue { applyLaunchAtLogin() } }
    }
    @Published var loginError: String?

    private let store: SettingsStore?
    private var persistCancellable: AnyCancellable?

    init(store: SettingsStore? = SettingsStore.appGroupStore()) {
        self.store = store
        fileTypes = store?.fileTypes ?? SeedPresets.builtIns
        useRightClickSubmenu = store?.useRightClickSubmenu ?? true
        createInSelectedFolder = store?.createInSelectedFolder ?? false
        showMenuBarItem = store?.showMenuBarItem ?? true
        showDockIcon = store?.showDockIcon ?? false
        launchAtLogin = SMAppService.mainApp.status == .enabled

        persistCancellable = $fileTypes
            .dropFirst()
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [store] types in store?.fileTypes = types }
    }

    func save(_ entry: FileTypeEntry) {
        if let index = fileTypes.firstIndex(where: { $0.id == entry.id }) {
            fileTypes[index] = entry
        } else {
            fileTypes.append(entry)
        }
    }

    func delete(_ entry: FileTypeEntry) {
        fileTypes.removeAll { $0.id == entry.id }
    }

    func move(from source: IndexSet, to destination: Int) {
        fileTypes.move(fromOffsets: source, toOffset: destination)
    }

    /// Nufi must stay reachable: turning off the last visible surface turns
    /// the other one on.
    private func appearanceChanged(menuBar: Bool) {
        if !showMenuBarItem && !showDockIcon {
            if menuBar { showDockIcon = true } else { showMenuBarItem = true }
            return
        }
        store?.showMenuBarItem = showMenuBarItem
        store?.showDockIcon = showDockIcon
        NotificationCenter.default.post(name: NufiNotification.appearanceChanged, object: nil)
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
