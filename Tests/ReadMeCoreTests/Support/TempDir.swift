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
}
