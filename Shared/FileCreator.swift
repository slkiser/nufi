import Foundation

enum FileCreator {
    enum Error: Swift.Error, Equatable {
        case emptyContent
    }

    static let pasteBaseName = "Pasted Text"
    static let pasteExtensions = ["txt", "md"]

    /// Writes UTF-8 bytes to a collision-safe URL. Never overwrites an existing file.
    /// Paste callers pass `allowEmpty: false` so a paste action cannot create a blank file.
    static func write(
        in directory: URL,
        baseName: String,
        ext: String,
        utf8Content: String,
        allowEmpty: Bool,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        writeData: (Data, URL) throws -> Void = { data, url in
            try data.write(to: url, options: [.withoutOverwriting])
        }
    ) throws -> URL {
        if !allowEmpty && utf8Content.isEmpty {
            throw Error.emptyContent
        }
        let url = FilenameGenerator.uniqueFileURL(
            in: directory,
            baseName: baseName,
            ext: ext,
            fileExists: fileExists
        )
        try writeData(Data(utf8Content.utf8), url)
        return url
    }
}
