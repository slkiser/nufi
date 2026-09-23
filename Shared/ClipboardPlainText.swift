import AppKit

enum ClipboardPlainText {
    /// Finder paste actions use the clipboard's plain-text representation only.
    /// Empty strings and non-text pasteboards yield nil so we never create a
    /// blank file under a paste label.
    static func read(from pasteboard: NSPasteboard = .general) -> String? {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            return nil
        }
        return text
    }
}
