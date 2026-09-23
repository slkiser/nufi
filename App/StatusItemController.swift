import AppKit
import os

private let log = Logger(subsystem: "dev.slkiser.nufi", category: "menubar")

/// Nufi's menu bar item. Creates files in the folder Finder is showing:
/// the frontmost Finder window, or the Desktop when the wallpaper is in
/// front. Finder Sync never attaches to the wallpaper, so this is the path
/// that covers the Desktop.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private var store: SettingsStore? { SettingsStore.appGroupStore() }

    private enum Action {
        case blank(FileTypeEntry)
        case paste(ext: String)
    }
    private var actions: [Action] = []
    private var destination: URL?

    func applySettings() {
        let wanted = store?.showMenuBarItem ?? true
        if wanted {
            install()
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "doc.badge.plus",
                                accessibilityDescription: "Nufi")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Nufi: new file in the current Finder folder"
        }
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        statusItem = item
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        actions = []
        destination = FinderLocation.current() ?? FinderLocation.desktop

        let header = NSMenuItem(
            title: "New in \(FinderLocation.displayName(for: destination!))",
            action: nil, keyEquivalent: ""
        )
        header.isEnabled = false
        header.toolTip = destination!.path
        menu.addItem(header)

        let entries = store?.enabledTypes ?? []
        if entries.isEmpty {
            let empty = NSMenuItem(title: "Enable a file type in Settings…",
                                   action: #selector(openSettings), keyEquivalent: "")
            empty.target = self
            menu.addItem(empty)
        }
        for entry in entries {
            let row = NSMenuItem(title: entry.menuTitle,
                                 action: #selector(runMenuAction(_:)), keyEquivalent: "")
            row.target = self
            row.tag = actions.count
            row.image = Self.symbol("doc")
            actions.append(.blank(entry))
            menu.addItem(row)
        }

        menu.addItem(.separator())
        let hasText = ClipboardPlainText.read() != nil
        for ext in FileCreator.pasteExtensions {
            let row = NSMenuItem(title: "Paste as .\(ext)",
                                 action: #selector(runMenuAction(_:)), keyEquivalent: "")
            row.target = self
            row.tag = actions.count
            row.image = Self.symbol("doc.on.clipboard")
            row.isEnabled = hasText
            row.toolTip = hasText ? nil : "Copy some text first"
            actions.append(.paste(ext: ext))
            menu.addItem(row)
        }

        menu.addItem(.separator())
        if !SetupStatus.current().isComplete {
            let setup = NSMenuItem(title: "Finish Setup…", action: #selector(openOnboarding),
                                   keyEquivalent: "")
            setup.target = self
            setup.image = Self.symbol("exclamationmark.circle")
            menu.addItem(setup)
        }
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings),
                                  keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Nufi", action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    // MARK: Actions

    @objc private func runMenuAction(_ sender: NSMenuItem) {
        guard actions.indices.contains(sender.tag), let directory = destination else {
            NSSound.beep()
            return
        }
        do {
            let url: URL
            switch actions[sender.tag] {
            case .blank(let entry):
                url = try FileCreator.write(in: directory, baseName: entry.baseName,
                                            ext: entry.ext, utf8Content: entry.template,
                                            allowEmpty: true)
            case .paste(let ext):
                guard let text = ClipboardPlainText.read() else {
                    NSSound.beep()
                    return
                }
                url = try FileCreator.write(in: directory, baseName: FileCreator.pasteBaseName,
                                            ext: ext, utf8Content: text, allowEmpty: false)
            }
            log.info("menubar created \(url.path, privacy: .public)")
            DistributedNotificationCenter.default().postNotificationName(
                NufiNotification.toolbarOrMenuUsed, object: nil, userInfo: nil,
                deliverImmediately: true)
            FinderInlineRename.beginRenaming(fileAt: url)
        } catch {
            log.error("menubar create failed: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = "Nufi couldn't create the file"
            alert.informativeText = "\(FinderLocation.displayName(for: directory)): \(error.localizedDescription)"
            alert.runModal()
        }
    }

    @objc private func openSettings() {
        Windows.shared.showSettings()
    }

    @objc private func openOnboarding() {
        Windows.shared.showOnboarding()
    }

    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }
}
