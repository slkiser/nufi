import XCTest

final class CreationDestinationTests: XCTestCase {

    private let folder = URL(fileURLWithPath: "/Users/me/Downloads/nufi-alpha-test", isDirectory: true)
    private let nested = URL(fileURLWithPath: "/Users/me/Downloads/project", isDirectory: true)

    func testOpenFolderBackground_usesTargetedURL() {
        let url = CreationDestination.directory(
            kind: .container, targetedURL: folder,
            selectedFolder: nil, createInSelectedFolder: false)
        XCTAssertEqual(url, folder)
    }

    func testNilTarget_createsNothing() {
        for kind in [CreationDestination.MenuKind.container, .items, .other] {
            let url = CreationDestination.directory(
                kind: kind, targetedURL: nil,
                selectedFolder: nil, createInSelectedFolder: false)
            XCTAssertNil(url)
        }
    }

    func testSelectedFolderMode_usesTheClickedFolder() {
        let url = CreationDestination.directory(
            kind: .items, targetedURL: folder,
            selectedFolder: nested, createInSelectedFolder: true)
        XCTAssertEqual(url, nested)
    }

    func testSelectedFolderMode_onlyAppliesToItemMenus() {
        let url = CreationDestination.directory(
            kind: .container, targetedURL: folder,
            selectedFolder: nested, createInSelectedFolder: true)
        XCTAssertEqual(url, folder)
    }

    func testSelectedFolderModeOff_ignoresClickedFolder() {
        let url = CreationDestination.directory(
            kind: .items, targetedURL: folder,
            selectedFolder: nested, createInSelectedFolder: false)
        XCTAssertEqual(url, folder)
    }

    func testResolvedDirectory_keepsFolders() {
        let url = CreationDestination.resolvedDirectory(for: folder, isDirectory: { _ in true })
        XCTAssertEqual(url, folder)
    }

    func testResolvedDirectory_filesUseParent() {
        let file = folder.appendingPathComponent("notes.txt")
        let url = CreationDestination.resolvedDirectory(for: file, isDirectory: { _ in false })
        XCTAssertEqual(url, folder)
    }
}
