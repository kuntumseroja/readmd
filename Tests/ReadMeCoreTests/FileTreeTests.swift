import Foundation
import Testing
@testable import ReadMeCore

struct FileTreeTests {
    @Test func rootChildrenHideJunkAndDotfiles() {
        let tree = FileTree(root: FixtureProject.root, rules: HideRules(showHidden: false))
        let names = tree.children(of: FixtureProject.root).map(\.name)
        #expect(names.contains("README.md"))
        #expect(names.contains("docs"))
        #expect(names.contains("src"))
        #expect(names.contains("assets"))
        #expect(names.contains("notes.bin"))
        #expect(!names.contains("node_modules"))
        #expect(!names.contains(".git"))
        #expect(!names.contains(".env"))
    }

    @Test func showHiddenRevealsDotfilesButNotJunk() {
        let tree = FileTree(root: FixtureProject.root, rules: HideRules(showHidden: true))
        let names = tree.children(of: FixtureProject.root).map(\.name)
        #expect(names.contains(".env"))
        #expect(!names.contains("node_modules"))
        #expect(!names.contains(".git"))
    }

    @Test func doesNotReadInsideCollapsedJunk() throws {
        try TempDir.make { dir in
            let junk = dir.appendingPathComponent("node_modules", isDirectory: true)
            let marker = junk.appendingPathComponent("touched.txt")
            try FileManager.default.createDirectory(at: junk, withIntermediateDirectories: true)
            try Data("x".utf8).write(to: marker)
            let tree = FileTree(root: dir, rules: HideRules(showHidden: true))
            _ = tree.children(of: dir)
            #expect(tree.children(of: dir).contains { $0.name == "node_modules" } == false)
        }
    }

    @Test func unreadableDirectoryYieldsNoChildren() throws {
        try TempDir.make { dir in
            let locked = dir.appendingPathComponent("locked", isDirectory: true)
            try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
            defer {
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
            }
            let tree = FileTree(root: dir, rules: HideRules())
            let rows = tree.children(of: dir)
            #expect(rows.contains { $0.name == "locked" && $0.isDirectory })
            #expect(tree.children(of: locked).isEmpty)
        }
    }

    @Test func expandingAncestorsIncludesRootAndParents() {
        let tree = FileTree(root: FixtureProject.root, rules: HideRules())
        let file = FixtureProject.root.appendingPathComponent("docs/guide.md")
        let ancestors = tree.expandingAncestors(to: file)
        #expect(ancestors.contains(FixtureProject.root))
        #expect(ancestors.contains(FixtureProject.root.appendingPathComponent("docs", isDirectory: true)))
    }

    @Test func childrenAreFoldersFirstThenLocalizedNames() {
        let tree = FileTree(root: FixtureProject.root, rules: HideRules())
        let names = tree.children(of: FixtureProject.root).map(\.name)
        let folders = names.filter { ["assets", "docs", "src"].contains($0) }
        #expect(folders == ["assets", "docs", "src"])
    }
}
