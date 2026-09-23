import Foundation

enum CreationDestination {
    enum MenuKind: Equatable {
        case container
        case items
        case other
    }

    /// Picks the folder that should receive a new file: the folder a
    /// right-clicked folder icon points at when that mode is on, otherwise the
    /// folder Finder targeted (the open window). No target means no creation;
    /// Nufi never guesses a folder.
    static func directory(
        kind: MenuKind,
        targetedURL: URL?,
        selectedFolder: URL?,
        createInSelectedFolder: Bool
    ) -> URL? {
        if kind == .items, createInSelectedFolder, let selectedFolder {
            return selectedFolder
        }
        return targetedURL
    }

    static func resolvedDirectory(
        for url: URL,
        isDirectory: (URL) -> Bool
    ) -> URL {
        isDirectory(url) ? url : url.deletingLastPathComponent()
    }
}
