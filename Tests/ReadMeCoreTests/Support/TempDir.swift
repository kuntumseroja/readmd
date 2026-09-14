import Foundation

enum TempDir {
    static func make(_ body: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("readme-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url)
    }
}

enum FixtureProject {
    static var root: URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // TempDir.swift
        url.deleteLastPathComponent() // Support
        url.deleteLastPathComponent() // ReadMeCoreTests
        url.deleteLastPathComponent() // Tests
        return url.appendingPathComponent("Fixtures/SampleProject", isDirectory: true)
    }

    /// Git will not track a nested `.git`; create a dummy HEAD so hide-junk tests see a real `.git` row.
    static func ensureDummyGit() throws {
        let gitDir = root.appendingPathComponent(".git", isDirectory: true)
        let head = gitDir.appendingPathComponent("HEAD")
        guard !FileManager.default.fileExists(atPath: head.path) else { return }
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        try Data("ref: refs/heads/main\n".utf8).write(to: head)
    }
}
