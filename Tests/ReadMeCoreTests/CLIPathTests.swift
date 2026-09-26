import Foundation
import Testing
@testable import ReadMeCore

struct CLIPathTests {
    @Test func noArgsMeansEmptyLaunch() {
        #expect(CLIArgs.resolvedPath(from: ["/usr/local/bin/read.me"]) == nil)
    }

    @Test func firstPathWins() {
        let cwd = FixtureProject.root
        let url = CLIArgs.resolvedPath(from: ["read.me", ".", "ignored"], cwd: cwd)
        #expect(url?.standardizedFileURL == cwd.standardizedFileURL)
    }

    @Test func expandsHome() {
        let url = CLIArgs.resolvedPath(from: ["read.me", "~"])
        #expect(url?.path == NSHomeDirectory())
    }
}
