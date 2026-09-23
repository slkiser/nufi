import AppKit

/// "Uninstall Nufi…" flow for local/DMG users. Quitting the app never stops the
/// Finder extension (Finder/pkd owns that process), so dragging the app to the
/// Trash reports "in use". This disables the appex first, then hands the
/// actual deletion to the user — nothing is removed without a drag to Trash.
@MainActor
enum UninstallHelper {
    static func run() {
        let confirm = NSAlert()
        confirm.messageText = "Uninstall Nufi?"
        confirm.informativeText = """
            This turns off the Finder extension and reveals Nufi in Finder \
            so you can drag it to the Trash. Nothing is deleted automatically.
            """
        confirm.alertStyle = .warning
        confirm.addButton(withTitle: "Continue")
        confirm.addButton(withTitle: "Cancel")
        let removeSettings = NSButton(
            checkboxWithTitle: "Also remove my saved file types",
            target: nil, action: nil
        )
        removeSettings.state = .off
        confirm.accessoryView = removeSettings
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        // Stop Finder from loading the appex, then end the running instance.
        // The pkill pattern matches the appex path only, never the host app.
        runTool("/usr/bin/pluginkit",
                ["-e", "ignore", "-i", NufiIdentity.finderExtensionBundleID])
        runTool("/usr/bin/pkill", ["-f", "NufiExtension.appex"])

        if removeSettings.state == .on {
            let group = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Group Containers/\(SettingsStore.appGroupID)")
            try? FileManager.default.removeItem(at: group)
        }

        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])

        let done = NSAlert()
        done.messageText = "Finder extension disabled"
        done.informativeText = "To finish, drag Nufi to the Trash. Nufi will now quit."
        done.addButton(withTitle: "Quit Nufi")
        done.runModal()
        NSApp.terminate(nil)
    }

    private static func runTool(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
    }
}
