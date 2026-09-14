import Foundation
import Testing
@testable import ReadMeCore

struct ReaderControllerTests {
    @Test func selectMarkdownLoadsPreview() {
        var reader = ReaderController()
        reader.open(FixtureProject.root)
        reader.select(FixtureProject.root.appendingPathComponent("README.md"))
        guard case .markdown = reader.preview else {
            Issue.record("expected markdown preview")
            return
        }
    }

    @Test func handleRelativeLinkSelectsTarget() {
        var reader = ReaderController()
        reader.open(FixtureProject.root)
        reader.select(FixtureProject.root.appendingPathComponent("README.md"))
        reader.handleLink("docs/guide.md")
        #expect(reader.session.selectedURL?.lastPathComponent == "guide.md")
        guard case .markdown(let text) = reader.preview else {
            Issue.record("expected markdown")
            return
        }
        #expect(text.contains("# Guide"))
    }

    @Test func handleExternalLinkDoesNotChangeSelection() {
        var reader = ReaderController()
        reader.open(FixtureProject.root)
        let file = FixtureProject.root.appendingPathComponent("README.md")
        reader.select(file)
        reader.handleLink("https://example.com")
        #expect(reader.session.selectedURL?.standardizedFileURL == file.standardizedFileURL)
        #expect(reader.linkDecision(for: "https://example.com") == .openExternal(URL(string: "https://example.com")!))
    }

    @Test func failedOpenSetsErrorAndKeepsFolder() {
        var reader = ReaderController()
        reader.open(FixtureProject.root)
        reader.open(FixtureProject.root.appendingPathComponent("no-such-folder"))
        #expect(reader.openError == .missing)
        #expect(reader.session.folderURL?.standardizedFileURL == FixtureProject.root.standardizedFileURL)
    }

    @Test func emptyStateCopyLivesInContentView() throws {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // ReaderControllerTests.swift
        url.deleteLastPathComponent() // ReadMeCoreTests
        url.deleteLastPathComponent() // Tests
        let contentView = url.appendingPathComponent("Sources/ReadMe/ContentView.swift")
        let source = try String(contentsOf: contentView, encoding: .utf8)
        #expect(source.contains("Open a folder"))
        #expect(source.contains("⌘O or read.me ."))
    }
}
