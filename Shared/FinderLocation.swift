import Foundation

enum FinderLocation {
    /// Finder's insertion location: the folder shown in the frontmost Finder
    /// window, or the Desktop when no window is open or the wallpaper is
    /// frontmost. This is the same folder Finder's own File > New Folder uses.
    static func current() -> URL? {
        var error: NSDictionary?
        let result = NSAppleScript(source: """
            tell application "Finder"
                try
                    POSIX path of (insertion location as alias)
                end try
            end tell
            """)?.executeAndReturnError(&error)
        guard error == nil,
              let path = result?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static var desktop: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop", isDirectory: true)
    }

    /// Short label for a folder, as Finder shows it ("Desktop", "Downloads").
    static func displayName(for url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.isEmpty ? url.lastPathComponent : name
    }
}
