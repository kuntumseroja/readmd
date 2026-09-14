import Foundation
import Testing
@testable import ReadMeCore

struct FileLoaderTests {
    let loader = FileLoader()

    @Test func classifiesMarkdown() {
        let url = FixtureProject.root.appendingPathComponent("README.md")
        guard case .markdown(let text) = loader.load(url: url) else {
            Issue.record("expected markdown")
            return
        }
        #expect(text.contains("# Sample"))
    }

    @Test func classifiesSwiftAsText() {
        let url = FixtureProject.root.appendingPathComponent("src/main.swift")
        guard case .text(let text, let language) = loader.load(url: url) else {
            Issue.record("expected text")
            return
        }
        #expect(language == "swift")
        #expect(text.contains("print"))
    }

    @Test func classifiesPngAsImage() {
        let url = FixtureProject.root.appendingPathComponent("assets/dot.png")
        guard case .image(let imageURL) = loader.load(url: url) else {
            Issue.record("expected image")
            return
        }
        #expect(imageURL.standardizedFileURL == url.standardizedFileURL)
    }

    @Test func classifiesBinaryNotes() {
        let url = FixtureProject.root.appendingPathComponent("notes.bin")
        guard case .unavailable(_, _, _, let reason) = loader.load(url: url) else {
            Issue.record("expected unavailable")
            return
        }
        #expect(reason == .binary || reason == .notText)
    }

    @Test func rejectsHugeFilesWithoutReadingThemAsText() throws {
        try TempDir.make { dir in
            let url = dir.appendingPathComponent("big.md")
            let handle = try FileHandle(forWritingTo: {
                FileManager.default.createFile(atPath: url.path, contents: nil)
                return url
            }())
            try handle.truncate(atOffset: UInt64(FileLoader.maxByteCount + 1))
            try handle.close()
            guard case .unavailable(_, let size, _, .tooLarge) = loader.load(url: url) else {
                Issue.record("expected tooLarge")
                return
            }
            #expect(size == Int64(FileLoader.maxByteCount + 1))
        }
    }

    @Test func invalidUTF8IsNotText() throws {
        try TempDir.make { dir in
            let url = dir.appendingPathComponent("bad.txt")
            try Data([0xC3, 0x28]).write(to: url)
            guard case .unavailable(_, _, _, let reason) = loader.load(url: url) else {
                Issue.record("expected unavailable")
                return
            }
            #expect(reason == .notText)
        }
    }

    @Test func missingFileIsUnreadable() {
        let url = FixtureProject.root.appendingPathComponent("nope.txt")
        guard case .unavailable(_, _, _, .unreadable) = loader.load(url: url) else {
            Issue.record("expected unreadable")
            return
        }
    }
}
