import Foundation
import Testing
@testable import ReadMeCore

struct AppSessionTests {
    @Test func opensDirectory() {
        var session = AppSession()
        let result = session.open(FixtureProject.root)
        guard case .success(let opened) = result else {
            Issue.record("expected success")
            return
        }
        #expect(opened.folderURL.standardizedFileURL == FixtureProject.root.standardizedFileURL)
        #expect(opened.selectedURL == nil)
        #expect(session.folderURL == opened.folderURL)
    }

    @Test func opensFileByUsingParent() {
        var session = AppSession()
        let file = FixtureProject.root.appendingPathComponent("README.md")
        let result = session.open(file)
        guard case .success(let opened) = result else {
            Issue.record("expected success")
            return
        }
        #expect(opened.folderURL.standardizedFileURL == FixtureProject.root.standardizedFileURL)
        #expect(opened.selectedURL?.standardizedFileURL == file.standardizedFileURL)
    }

    @Test func missingPathFailsAndKeepsPrevious() {
        var session = AppSession()
        _ = session.open(FixtureProject.root)
        let previous = session
        let result = session.open(FixtureProject.root.appendingPathComponent("missing-dir"))
        #expect(result == .failure(.missing))
        #expect(session == previous)
    }

    @Test func closeFolderClearsState() {
        var session = AppSession()
        _ = session.open(FixtureProject.root)
        session.closeFolder()
        #expect(session.folderURL == nil)
        #expect(session.selectedURL == nil)
    }
}
