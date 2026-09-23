import Cocoa
import FinderSync
import os

private let log = Logger(subsystem: "dev.slkiser.nufi", category: "extension")

private enum FinderMenuAction {
    case blank(FileTypeEntry)
    case paste(ext: String)
}

final class FinderSync: FIFinderSync {

    private let settings: SettingsStore? = SettingsStore.appGroupStore()

    // Snapshot of actions indexed by NSMenuItem.tag at menu-construction time.
    // representedObject can't carry a Swift enum across the FinderSync XPC bridge,
    // so the action handler looks the action up by tag instead.
    private var menuActions: [FinderMenuAction] = []
    private var currentMenuKind: FIMenuKind = .contextualMenuForContainer

    override init() {
        super.init()
        let controller = FIFinderSyncController.default()
        controller.directoryURLs = Self.watchedDirectories()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { _ in
            controller.directoryURLs = Self.watchedDirectories()
        }
        log.info("FinderSync init")
    }

    /// Every mounted volume, so any open Finder folder gets the menu. Finder
    /// Sync never asks for a menu on the Desktop wallpaper; the host app's
    /// menu bar item covers that surface.
    private static func watchedDirectories() -> Set<URL> {
        var urls: Set<URL> = [URL(fileURLWithPath: "/")]
        if let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) {
            urls.formUnion(volumes)
        }
        return urls
    }

    // MARK: - Toolbar item

    override var toolbarItemName: String { "Nufi" }

    override var toolbarItemToolTip: String { "Create a new file in this folder" }

    override var toolbarItemImage: NSImage {
        Self.toolbarIcon(accessibility: "New File")
    }

    // MARK: - Menus

    override func menu(for menu: FIMenuKind) -> NSMenu? {
        currentMenuKind = menu
        let targetPath = FIFinderSyncController.default().targetedURL()?.path ?? "nil"
        let selectedCount = FIFinderSyncController.default().selectedItemURLs()?.count ?? 0
        log.info("menu kind=\(String(describing: menu), privacy: .public) target=\(targetPath, privacy: .public) selected=\(selectedCount)")
        switch menu {
        case .contextualMenuForItems:
            return selectedFolderContextMenu()
        case .toolbarItemMenu:
            return buildToolbarMenu()
        case .contextualMenuForContainer:
            return buildContextMenu()
        default:
            return buildContextMenu()
        }
    }

    private func selectedFolderContextMenu() -> NSMenu? {
        guard settings?.createInSelectedFolder == true,
              selectedDirectory() != nil else {
            return nil
        }
        return buildContextMenu()
    }

    private func buildToolbarMenu() -> NSMenu {
        let menu = NSMenu(title: "")
        menu.autoenablesItems = false
        menuActions = []
        appendBlankFileItems(to: menu, forceFlat: true)
        appendPasteItems(to: menu)
        menu.addItem(NSMenuItem.separator())
        appendCustomizeRow(to: menu)
        return menu
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu(title: "")
        menu.autoenablesItems = false
        menuActions = []
        appendBlankFileItems(to: menu, forceFlat: false)
        appendPasteItems(to: menu)
        return menu
    }

    private func appendBlankFileItems(to menu: NSMenu, forceFlat: Bool) {
        let entries = settings?.enabledTypes ?? []
        if entries.isEmpty {
            appendEmptyRow(to: menu)
            return
        }
        let useSubmenu = !forceFlat && (settings?.useRightClickSubmenu == true)
        if useSubmenu {
            let parent = NSMenuItem(title: "New File", action: nil, keyEquivalent: "")
            parent.image = Self.menuIcon()
            let sub = NSMenu(title: "")
            for entry in entries { addBlankRow(for: entry, to: sub) }
            parent.submenu = sub
            menu.addItem(parent)
        } else {
            for entry in entries { addBlankRow(for: entry, to: menu) }
        }
    }

    private func appendPasteItems(to menu: NSMenu) {
        let hasText = ClipboardPlainText.read() != nil
        let parent = NSMenuItem(title: "Paste as New File", action: nil, keyEquivalent: "")
        parent.image = Self.pasteIcon()
        parent.isEnabled = hasText
        let sub = NSMenu(title: "")
        for ext in FileCreator.pasteExtensions {
            let item = NSMenuItem(
                title: ".\(ext)",
                action: #selector(createFromMenuItem(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.isEnabled = hasText
            item.tag = menuActions.count
            menuActions.append(.paste(ext: ext))
            sub.addItem(item)
        }
        parent.submenu = sub
        menu.addItem(parent)
    }

    private func appendCustomizeRow(to menu: NSMenu) {
        let item = NSMenuItem(
            title: "Customize…",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
    }

    private func appendEmptyRow(to menu: NSMenu) {
        let item = NSMenuItem(
            title: "Enable a file type in Nufi…",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
    }

    @objc func openPreferences(_ sender: AnyObject?) {
        log.info("openPreferences requested")
        // Latch the launch-intent BEFORE posting the notification + opening
        // the host. If the app is already running, the observer fires and
        // clears the latch immediately. If the app needs to launch, the
        // notification beats the observer's registration; the AppDelegate
        // checks-and-clears the latch on launch as a fallback.
        settings?.pendingOpenPreferences = true
        DistributedNotificationCenter.default().postNotificationName(
            NufiNotification.openPreferences,
            object: nil, userInfo: nil, deliverImmediately: true
        )
        if let url = hostAppURL() {
            NSWorkspace.shared.open(url)
        }
    }

    /// The app presses keys in Finder, not the extension, so the user grants
    /// Accessibility and Automation to Nufi once. Launches the app if needed;
    /// the latch survives the launch because the notification would not.
    private func requestRename(_ url: URL) {
        settings?.pendingRenamePath = url.path
        DistributedNotificationCenter.default().postNotificationName(
            NufiNotification.renameRequested,
            object: nil, userInfo: nil, deliverImmediately: true
        )
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: NufiIdentity.appBundleID)
        if running.isEmpty, let host = hostAppURL() {
            NSWorkspace.shared.openApplication(at: host, configuration: .init())
        }
    }

    private func hostAppURL() -> URL? {
        // Extension bundle is .../Nufi.app/Contents/PlugIns/NufiExtension.appex.
        // Walk up four levels to land on the host app.
        let bundle = Bundle(for: FinderSync.self).bundleURL
        return bundle
            .deletingLastPathComponent()  // PlugIns
            .deletingLastPathComponent()  // Contents
            .deletingLastPathComponent()  // Nufi.app
    }

    private func addBlankRow(for entry: FileTypeEntry, to menu: NSMenu) {
        let item = NSMenuItem(
            title: entry.menuTitle,
            action: #selector(createFromMenuItem(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = Self.menuIcon()
        item.tag = menuActions.count
        menuActions.append(.blank(entry))
        menu.addItem(item)
    }

    private static func toolbarIcon(accessibility: String?) -> NSImage {
        let image = NSImage(systemSymbolName: "square.and.pencil",
                            accessibilityDescription: accessibility)
            ?? NSImage()
        image.isTemplate = true
        return image
    }

    private static func menuIcon() -> NSImage {
        symbol("square.and.pencil", accessibility: "New File")
    }

    private static func pasteIcon() -> NSImage {
        symbol("doc.on.clipboard", accessibility: "Paste as New File")
    }

    private static func symbol(_ name: String, accessibility: String) -> NSImage {
        guard let base = NSImage(systemSymbolName: name,
                                 accessibilityDescription: accessibility) else {
            return NSImage()
        }
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    // MARK: - Actions

    @objc func createFromMenuItem(_ sender: AnyObject?) {
        guard let item = sender as? NSMenuItem,
              menuActions.indices.contains(item.tag) else {
            log.error("createFromMenuItem: tag \(((sender as? NSMenuItem)?.tag ?? -1)) out of range (snapshot=\(self.menuActions.count))")
            NSSound.beep()
            return
        }
        switch menuActions[item.tag] {
        case .blank(let entry):
            performBlank(entry: entry)
        case .paste(let ext):
            performPaste(ext: ext)
        }
    }

    private func performBlank(entry: FileTypeEntry) {
        log.info("create blank entry=\(entry.menuTitle, privacy: .public) ext=\(entry.ext, privacy: .public)")
        notifyUsed()
        guard let directory = destinationDirectory() else {
            log.error("No target directory available")
            NSSound.beep()
            return
        }
        do {
            let url = try createFile(contents: entry.template, baseName: entry.baseName, ext: entry.ext, in: directory, allowEmpty: true)
            log.info("created file=\(url.path, privacy: .public)")
            requestRename(url)
        } catch {
            log.error("create failed: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
        }
    }

    private func performPaste(ext: String) {
        log.info("paste ext=\(ext, privacy: .public)")
        guard let text = ClipboardPlainText.read() else {
            log.error("paste refused: clipboard has no plain text")
            NSSound.beep()
            return
        }
        notifyUsed()
        guard let directory = destinationDirectory() else {
            log.error("No target directory available")
            NSSound.beep()
            return
        }
        do {
            let url = try createFile(
                contents: text,
                baseName: FileCreator.pasteBaseName,
                ext: ext,
                in: directory,
                allowEmpty: false
            )
            log.info("pasted file=\(url.path, privacy: .public)")
            requestRename(url)
        } catch {
            log.error("paste failed: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
        }
    }

    private func notifyUsed() {
        DistributedNotificationCenter.default().postNotificationName(
            NufiNotification.toolbarOrMenuUsed,
            object: nil, userInfo: nil, deliverImmediately: true
        )
    }

    // MARK: - Helpers

    private func createFile(
        contents: String,
        baseName: String,
        ext: String,
        in directory: URL,
        allowEmpty: Bool
    ) throws -> URL {
        let scoped = directory.startAccessingSecurityScopedResource()
        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
        return try FileCreator.write(
            in: directory,
            baseName: baseName,
            ext: ext,
            utf8Content: contents,
            allowEmpty: allowEmpty
        )
    }

    private func destinationDirectory() -> URL? {
        let controller = FIFinderSyncController.default()
        let kind: CreationDestination.MenuKind
        switch currentMenuKind {
        case .contextualMenuForItems: kind = .items
        case .contextualMenuForContainer: kind = .container
        default: kind = .other
        }
        let selected = (kind == .items) ? selectedDirectory() : nil
        return CreationDestination.directory(
            kind: kind,
            targetedURL: controller.targetedURL().map { resolvedDirectory(for: $0) },
            selectedFolder: selected,
            createInSelectedFolder: settings?.createInSelectedFolder == true
        )
    }

    private func selectedDirectory() -> URL? {
        let selected = FIFinderSyncController.default().selectedItemURLs() ?? []
        guard selected.count == 1, let url = selected.first else { return nil }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
              isDir.boolValue else {
            return nil
        }
        return url
    }

    private func resolvedDirectory(for url: URL) -> URL {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
           isDir.boolValue {
            return url
        }
        return url.deletingLastPathComponent()
    }
}
