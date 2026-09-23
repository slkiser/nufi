import XCTest
import AppKit

final class FileCreatorTests: XCTestCase {

    private func makeDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nufi-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testWriteTxt_preservesContents() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try FileCreator.write(
            in: dir, baseName: "Pasted Text", ext: "txt",
            utf8Content: "hello txt", allowEmpty: false
        )
        XCTAssertEqual(url.lastPathComponent, "Pasted Text.txt")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "hello txt")
    }

    func testWriteMd_preservesContents() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try FileCreator.write(
            in: dir, baseName: "Pasted Text", ext: "md",
            utf8Content: "# Title\n\nbody", allowEmpty: false
        )
        XCTAssertEqual(url.lastPathComponent, "Pasted Text.md")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "# Title\n\nbody")
    }

    func testWrite_preservesUnicodeAndLineBreaks() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let text = "café 日本語\nline 2\r\n🎉 third"
        let url = try FileCreator.write(
            in: dir, baseName: "Pasted Text", ext: "txt",
            utf8Content: text, allowEmpty: false
        )
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), text)
    }

    func testWrite_collisionUsesNumberedName() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = try FileCreator.write(
            in: dir, baseName: "Pasted Text", ext: "txt",
            utf8Content: "one", allowEmpty: false
        )
        let second = try FileCreator.write(
            in: dir, baseName: "Pasted Text", ext: "txt",
            utf8Content: "two", allowEmpty: false
        )
        XCTAssertEqual(first.lastPathComponent, "Pasted Text.txt")
        XCTAssertEqual(second.lastPathComponent, "Pasted Text 2.txt")
        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "one")
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "two")
    }

    func testWrite_doesNotOverwriteExisting() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let existing = dir.appendingPathComponent("Pasted Text.txt")
        try Data("keep me".utf8).write(to: existing, options: [.withoutOverwriting])
        let created = try FileCreator.write(
            in: dir, baseName: "Pasted Text", ext: "txt",
            utf8Content: "new", allowEmpty: false
        )
        XCTAssertEqual(created.lastPathComponent, "Pasted Text 2.txt")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "keep me")
    }

    func testEmptyPasteContent_throwsAndWritesNothing() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        var wrote = false
        XCTAssertThrowsError(
            try FileCreator.write(
                in: dir, baseName: "Pasted Text", ext: "txt",
                utf8Content: "", allowEmpty: false,
                writeData: { _, _ in wrote = true }
            )
        ) { error in
            XCTAssertEqual(error as? FileCreator.Error, .emptyContent)
        }
        XCTAssertFalse(wrote)
        let items = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        XCTAssertTrue(items.isEmpty)
    }

    func testBlankFile_allowsEmptyContent() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try FileCreator.write(
            in: dir, baseName: "New Text File", ext: "txt",
            utf8Content: "", allowEmpty: true
        )
        XCTAssertEqual(url.lastPathComponent, "New Text File.txt")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "")
    }
}

final class ClipboardPlainTextTests: XCTestCase {

    private func uniquePasteboard() -> NSPasteboard {
        NSPasteboard.withUniqueName()
    }

    func testEmptyClipboard_returnsNil() {
        let pb = uniquePasteboard()
        pb.clearContents()
        XCTAssertNil(ClipboardPlainText.read(from: pb))
    }

    func testEmptyString_returnsNil() {
        let pb = uniquePasteboard()
        pb.clearContents()
        pb.setString("", forType: .string)
        XCTAssertNil(ClipboardPlainText.read(from: pb))
    }

    func testPlainText_isReturnedUnchanged() {
        let pb = uniquePasteboard()
        pb.clearContents()
        pb.setString("café\n🎉", forType: .string)
        XCTAssertEqual(ClipboardPlainText.read(from: pb), "café\n🎉")
    }

    func testNonTextClipboard_returnsNil() {
        let pb = uniquePasteboard()
        pb.clearContents()
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
        image.unlockFocus()
        XCTAssertTrue(pb.writeObjects([image]))
        XCTAssertNil(ClipboardPlainText.read(from: pb))
    }
}

final class FinderInlineRenameTests: XCTestCase {

    func testStringLiteral_escapesQuotesAndBackslashes() {
        let literal = FinderInlineRename.appleScriptStringLiteral(#"/tmp/say "hi"\file.txt"#)
        XCTAssertEqual(literal, #""/tmp/say \"hi\"\\file.txt""#)
    }

    func testScript_selectsPathAndSendsKeypadEnter() {
        let url = URL(fileURLWithPath: "/tmp/Pasted Text.md")
        let source = FinderInlineRename.appleScriptSource(for: url)
        XCTAssertTrue(source.contains("/tmp/Pasted Text.md"))
        XCTAssertTrue(source.contains("key code 76"))
        XCTAssertTrue(source.contains("tell application \"Finder\""))
    }
}
