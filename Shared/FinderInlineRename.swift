import AppKit
import Foundation

enum FinderInlineRename {
    /// Selects `url` in Finder and sends keypad Enter (key code 76) once,
    /// which starts inline rename in icon, list, and column view. Return (36)
    /// would open the file in list view instead. Enter is sent exactly once:
    /// a second press commits the rename that the first one started.
    static func beginRenaming(fileAt url: URL, after delay: TimeInterval = 0.35) {
        NSWorkspace.shared.selectFile(
            url.path,
            inFileViewerRootedAtPath: url.deletingLastPathComponent().path
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            execute(appleScriptSource(for: url))
        }
    }

    static func appleScriptSource(for url: URL) -> String {
        let pathLiteral = appleScriptStringLiteral(url.path)
        return """
        set posixPath to \(pathLiteral)
        set fileAlias to (POSIX file posixPath) as alias
        tell application "Finder"
            activate
            select fileAlias
        end tell
        delay 0.2
        \(keyPressSource)
        """
    }

    static let keyPressSource = """
        tell application "System Events"
            tell process "Finder"
                set frontmost to true
                key code 76
            end tell
        end tell
        """

    static func appleScriptStringLiteral(_ raw: String) -> String {
        let escaped = raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func execute(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("Nufi Finder rename: \(error)")
        }
    }
}
