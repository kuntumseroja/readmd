import Testing
@testable import ReadMeCore

struct HideRulesTests {
    @Test func hidesJunkDirectoriesEvenWhenShowHidden() {
        let rules = HideRules(showHidden: true)
        #expect(rules.isListed("node_modules", isDirectory: true) == false)
        #expect(rules.isListed(".git", isDirectory: true) == false)
        #expect(rules.isListed("out", isDirectory: true) == false)
    }

    @Test func hidesDotfilesUnlessShowHidden() {
        let hidden = HideRules(showHidden: false)
        #expect(hidden.isListed(".env", isDirectory: false) == false)
        #expect(hidden.isListed("README.md", isDirectory: false) == true)

        let shown = HideRules(showHidden: true)
        #expect(shown.isListed(".env", isDirectory: false) == true)
        #expect(shown.isListed("README.md", isDirectory: false) == true)
    }

    @Test func doesNotTreatAFileNamedBuildAsJunk() {
        let rules = HideRules(showHidden: false)
        #expect(rules.isListed("build", isDirectory: false) == true)
        #expect(rules.isListed("build", isDirectory: true) == false)
    }

    @Test func alwaysHiddenSetMatchesSpec() {
        let expected: Set<String> = [
            ".git", "node_modules", "dist", "build", ".next", "target",
            ".build", "DerivedData", ".venv", "venv", "__pycache__",
            ".turbo", ".cache", "coverage", "out",
        ]
        #expect(HideRules.alwaysHiddenDirectoryNames == expected)
    }
}
