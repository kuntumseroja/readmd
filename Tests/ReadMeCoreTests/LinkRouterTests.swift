import Foundation
import Testing
@testable import ReadMeCore

struct LinkRouterTests {
    var router: LinkRouter {
        LinkRouter(
            folderURL: FixtureProject.root,
            currentFileURL: FixtureProject.root.appendingPathComponent("README.md")
        )
    }

    @Test func relativeDocSelects() {
        let decision = router.decide(href: "./docs/guide.md")
        let expected = FixtureProject.root.appendingPathComponent("docs/guide.md").standardizedFileURL
        #expect(decision == .select(expected))
    }

    @Test func parentRelativeFromNestedFileSelects() {
        let nested = LinkRouter(
            folderURL: FixtureProject.root,
            currentFileURL: FixtureProject.root.appendingPathComponent("docs/guide.md")
        )
        let expected = FixtureProject.root.appendingPathComponent("README.md").standardizedFileURL
        #expect(nested.decide(href: "../README.md") == .select(expected))
    }

    @Test func missingFileIsIgnored() {
        #expect(router.decide(href: "./nope.md") == .ignore)
    }

    @Test func escapeOutsideFolderIsIgnored() {
        #expect(router.decide(href: "../../etc/passwd") == .ignore)
    }

    @Test func httpsIsExternal() {
        let decision = router.decide(href: "https://example.com/doc")
        guard case .openExternal(let url) = decision else {
            Issue.record("expected external")
            return
        }
        #expect(url.absoluteString == "https://example.com/doc")
    }

    @Test func mailtoIsIgnored() {
        #expect(router.decide(href: "mailto:a@b.c") == .ignore)
    }
}
