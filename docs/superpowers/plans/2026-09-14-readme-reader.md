# read.me Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Mac-only SwiftUI app that opens a folder and lets you read markdown as a document and source as highlighted, read-only code.

**Architecture:** Testable logic lives in a SwiftPM library `ReadMeCore` (hide rules, lazy tree, file loader, link router, session/controller). A SwiftUI executable `ReadMe` renders the window. A CLI product `read.me` resolves a path and asks `NSWorkspace` to open `me.read.app`. No Chromium, no WKWebView, no file writes into the opened project.

**Tech Stack:** Swift 6, macOS 14, SwiftUI, Swift Testing, MarkdownUI, Splash, AppKit (`NSOpenPanel` / `NSWorkspace` / `NSImage` only).

## Global Constraints

- macOS 14.0+
- Native SwiftUI app, non-sandboxed (developer utility)
- Single process, single window; opening another folder replaces the current one
- Appearance follows macOS light/dark; no extra theme pack
- Display name: **read.me**. Bundle ID: `me.read.app`. CLI name: `read.me`
- No WKWebView. No Chromium. No Electron. No Tauri
- Hard cap: files larger than **2 MB** are not read
- The UI never writes project files; Copy from the reader is allowed
- No search, tabs, recents, reopen-last-folder, multi-window, git, outline, minimap, command palette, mermaid, math, hex, settings window, file-change watching, App Store / sandbox, Windows, Linux, CI
- Always-hidden directory names: `.git`, `node_modules`, `dist`, `build`, `.next`, `target`, `.build`, `DerivedData`, `.venv`, `venv`, `__pycache__`, `.turbo`, `.cache`, `coverage`, `out`
- Highlight languages: JavaScript, TypeScript, Python, Go, Rust, Swift, JSON, YAML, TOML, CSS, HTML, shell

---

## File structure

Create these files. Do not invent others unless a task says so.

| Path | Responsibility |
| --- | --- |
| `Package.swift` | Package: `ReadMeCore`, executable `ReadMe`, executable product `read.me` |
| `.gitignore` | Ignore `.build/`, `.swiftpm/`, `.DS_Store` |
| `Sources/ReadMeCore/HideRules.swift` | Which names appear in the tree |
| `Sources/ReadMeCore/FileTree.swift` | `FileNode`, lazy `children(of:)`, ancestor expansion |
| `Sources/ReadMeCore/FileLoader.swift` | `FilePreview`, `UnavailableReason`, classify + read |
| `Sources/ReadMeCore/LinkRouter.swift` | `LinkDecision` from an href + folder + current file |
| `Sources/ReadMeCore/AppSession.swift` | Open/close folder, selected URL, showHidden |
| `Sources/ReadMeCore/ReaderController.swift` | UI-facing state: open, select, load preview, follow links |
| `Sources/ReadMe/ReadMeApp.swift` | `@main` app, window, external-open wiring |
| `Sources/ReadMe/ReaderStore.swift` | Shared `ReaderController` for UI + AppDelegate |
| `Sources/ReadMe/AppDelegate.swift` | Dock / Finder / CLI file-open events |
| `Sources/ReadMe/ContentView.swift` | Split view, toolbar, menus, empty state, alerts |
| `Sources/ReadMe/FileTreeView.swift` | Sidebar outline |
| `Sources/ReadMe/ViewerView.swift` | Switch on `FilePreview` |
| `Sources/ReadMe/MarkdownDocumentView.swift` | Native GFM via MarkdownUI |
| `Sources/ReadMe/CodeDocumentView.swift` | Line numbers + Splash |
| `Sources/ReadMe/ImageDocumentView.swift` | `NSImage` preview |
| `Sources/ReadMe/UnavailableCard.swift` | Can’t-preview card |
| `Sources/ReadMe/Highlighting.swift` | Splash themes + keyword grammars |
| `Sources/ReadMeCLI/main.swift` | `read.me [path]` |
| `Tests/ReadMeCoreTests/HideRulesTests.swift` | Hide policy |
| `Tests/ReadMeCoreTests/FileTreeTests.swift` | Lazy tree + fixture |
| `Tests/ReadMeCoreTests/FileLoaderTests.swift` | Classification + 2 MB + UTF-8 |
| `Tests/ReadMeCoreTests/LinkRouterTests.swift` | Relative / escape / http |
| `Tests/ReadMeCoreTests/AppSessionTests.swift` | Open/close/replace |
| `Tests/ReadMeCoreTests/ReaderControllerTests.swift` | Preview + link follow |
| `Tests/ReadMeCoreTests/Support/TempDir.swift` | Temp directories for tests |
| `Fixtures/SampleProject/**` | Tiny fake project |
| `Info.plist` | Bundle ID, display name, folder document type, single instance |
| `scripts/bundle-app.sh` | Build Release and wrap `read.me.app` |

`FilePreview` is the spec’s `Preview` type. The name avoids clashing with SwiftUI `#Preview`.

---

### Task 1: Package and HideRules

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/ReadMeCore/HideRules.swift`
- Test: `Tests/ReadMeCoreTests/HideRulesTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `public struct HideRules: Equatable, Sendable` with `public var showHidden: Bool`, `public static let alwaysHiddenDirectoryNames: Set<String>`, `public func isListed(_ name: String, isDirectory: Bool) -> Bool`

- [ ] **Step 1: Write the failing test**

Create `Tests/ReadMeCoreTests/HideRulesTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter HideRulesTests
```

Expected: FAIL because `ReadMeCore` / `HideRules` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `.gitignore`:

```
.build/
.swiftpm/
.DS_Store
```

Create `Package.swift`:

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "read.me",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ReadMeCore", targets: ["ReadMeCore"]),
        .executable(name: "ReadMe", targets: ["ReadMe"]),
        .executable(name: "read.me", targets: ["ReadMeCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1"),
        .package(url: "https://github.com/JohnSundell/Splash", from: "0.16.0"),
    ],
    targets: [
        .target(name: "ReadMeCore"),
        .executableTarget(
            name: "ReadMe",
            dependencies: [
                "ReadMeCore",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Splash", package: "Splash"),
            ]
        ),
        .executableTarget(
            name: "ReadMeCLI",
            dependencies: ["ReadMeCore"]
        ),
        .testTarget(
            name: "ReadMeCoreTests",
            dependencies: ["ReadMeCore"]
        ),
    ]
)
```

Create stub executables so `swift test` can resolve the package. `Sources/ReadMe/ReadMeApp.swift`:

```swift
import SwiftUI

@main
struct ReadMeApp: App {
    var body: some Scene {
        WindowGroup {
            Text("read.me")
        }
    }
}
```

`Sources/ReadMeCLI/main.swift`:

```swift
print("read.me")
```

Create `Sources/ReadMeCore/HideRules.swift`:

```swift
public struct HideRules: Equatable, Sendable {
    public var showHidden: Bool

    public init(showHidden: Bool = false) {
        self.showHidden = showHidden
    }

    public static let alwaysHiddenDirectoryNames: Set<String> = [
        ".git", "node_modules", "dist", "build", ".next", "target",
        ".build", "DerivedData", ".venv", "venv", "__pycache__",
        ".turbo", ".cache", "coverage", "out",
    ]

    public func isListed(_ name: String, isDirectory: Bool) -> Bool {
        if isDirectory && Self.alwaysHiddenDirectoryNames.contains(name) {
            return false
        }
        if name.hasPrefix("."), !showHidden {
            return false
        }
        return true
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter HideRulesTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Package.swift .gitignore Sources/ReadMeCore/HideRules.swift Sources/ReadMe/ReadMeApp.swift Sources/ReadMeCLI/main.swift Tests/ReadMeCoreTests/HideRulesTests.swift
git commit -m "Add Swift package and hide rules for the file tree."
```

---

### Task 2: Sample fixture and FileTree

**Files:**
- Create: `Sources/ReadMeCore/FileTree.swift`
- Create: `Tests/ReadMeCoreTests/Support/TempDir.swift`
- Create: `Tests/ReadMeCoreTests/FileTreeTests.swift`
- Create: `Fixtures/SampleProject/README.md`
- Create: `Fixtures/SampleProject/docs/guide.md`
- Create: `Fixtures/SampleProject/src/main.swift`
- Create: `Fixtures/SampleProject/assets/dot.png`
- Create: `Fixtures/SampleProject/notes.bin`
- Create: `Fixtures/SampleProject/.env`
- Create: `Fixtures/SampleProject/.git/HEAD`
- Create: `Fixtures/SampleProject/node_modules/pkg/index.js`

**Interfaces:**
- Consumes: `HideRules.isListed(_:isDirectory:)`
- Produces: `public struct FileNode: Identifiable, Equatable, Sendable` with `url: URL`, `name: String`, `isDirectory: Bool`; `id` is `url`. `public struct FileTree: Equatable, Sendable` with `root: URL`, `rules: HideRules`, `init(root:rules:)`, `func children(of url: URL) -> [FileNode]`, `func expandingAncestors(to url: URL) -> [URL]`

- [ ] **Step 1: Write the fixture and failing tests**

`Fixtures/SampleProject/README.md`:

```markdown
# Sample

See [the guide](docs/guide.md).

![dot](assets/dot.png)
```

`Fixtures/SampleProject/docs/guide.md`:

```markdown
# Guide

Back to [README](../README.md).
```

`Fixtures/SampleProject/src/main.swift`:

```swift
print("hello")
```

`Fixtures/SampleProject/.env`:

```
SECRET=1
```

`Fixtures/SampleProject/.git/HEAD`:

```
ref: refs/heads/main
```

`Fixtures/SampleProject/node_modules/pkg/index.js`:

```javascript
module.exports = 1
```

`Fixtures/SampleProject/notes.bin`: write 8 bytes `00 01 02 03 04 05 FF FE` via:

```bash
printf '000102030405fffe' | xxd -r -p > Fixtures/SampleProject/notes.bin
```

`Fixtures/SampleProject/assets/dot.png`: write a 1×1 PNG:

```bash
mkdir -p Fixtures/SampleProject/assets
python3 -c "import base64,pathlib; pathlib.Path('Fixtures/SampleProject/assets/dot.png').write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='))"
```

`Tests/ReadMeCoreTests/Support/TempDir.swift`:

```swift
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
        url.deleteLastPathComponent() // Support
        url.deleteLastPathComponent() // ReadMeCoreTests
        url.deleteLastPathComponent() // Tests
        return url.appendingPathComponent("Fixtures/SampleProject", isDirectory: true)
    }
}
```

`Tests/ReadMeCoreTests/FileTreeTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter FileTreeTests
```

Expected: FAIL because `FileTree` does not exist.

- [ ] **Step 3: Write minimal implementation**

`Sources/ReadMeCore/FileTree.swift`:

```swift
import Foundation

public struct FileNode: Identifiable, Equatable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let isDirectory: Bool
}

public struct FileTree: Equatable, Sendable {
    public var root: URL
    public var rules: HideRules

    public init(root: URL, rules: HideRules = HideRules()) {
        self.root = root.standardizedFileURL
        self.rules = rules
    }

    public func children(of url: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }

        var nodes: [FileNode] = []
        for child in urls {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values?.isDirectory == true
            let name = child.lastPathComponent
            guard rules.isListed(name, isDirectory: isDirectory) else { continue }
            nodes.append(FileNode(url: child.standardizedFileURL, name: name, isDirectory: isDirectory))
        }

        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    public func expandingAncestors(to url: URL) -> [URL] {
        let rootPath = root.standardizedFileURL.path
        var current = url.standardizedFileURL.deletingLastPathComponent()
        var result: [URL] = []
        while current.path.hasPrefix(rootPath) {
            result.append(current)
            if current.path == rootPath { break }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        return result
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter FileTreeTests
```

Expected: PASS. If the unreadable-directory test fails because the process is root, skip that assertion only after confirming `getuid() == 0`; otherwise fix permissions handling.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReadMeCore/FileTree.swift Tests/ReadMeCoreTests/FileTreeTests.swift Tests/ReadMeCoreTests/Support/TempDir.swift Fixtures
git commit -m "Add a lazy file tree that hides junk folders."
```

---

### Task 3: FileLoader

**Files:**
- Create: `Sources/ReadMeCore/FileLoader.swift`
- Test: `Tests/ReadMeCoreTests/FileLoaderTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks except Foundation URLs
- Produces:

```swift
public enum UnavailableReason: Equatable, Sendable {
    case binary, tooLarge, notText, permissionDenied, unreadable
}

public enum FilePreview: Equatable, Sendable {
    case markdown(String)
    case text(String, language: String?)
    case image(URL)
    case unavailable(name: String, size: Int64, type: String, reason: UnavailableReason)
}

public struct FileLoader: Equatable, Sendable {
    public static let maxByteCount = 2 * 1024 * 1024
    public var maxByteCount: Int
    public init(maxByteCount: Int = FileLoader.maxByteCount)
    public func load(url: URL) -> FilePreview
}
```

Language from extension: `js/mjs/cjs/jsx` → `"javascript"`; `ts/tsx` → `"typescript"`; `py` → `"python"`; `go` → `"go"`; `rs` → `"rust"`; `swift` → `"swift"`; `json` → `"json"`; `yml/yaml` → `"yaml"`; `toml` → `"toml"`; `css` → `"css"`; `html/htm` → `"html"`; `sh/bash/zsh` → `"shell"`; else `nil`. Markdown extensions: `md`, `markdown`, `mdown`. Image extensions: `png`, `jpg`, `jpeg`, `gif`, `webp`, `svg`.

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter FileLoaderTests
```

Expected: FAIL because `FileLoader` does not exist.

- [ ] **Step 3: Write minimal implementation**

`Sources/ReadMeCore/FileLoader.swift`:

```swift
import Foundation

public enum UnavailableReason: Equatable, Sendable {
    case binary
    case tooLarge
    case notText
    case permissionDenied
    case unreadable
}

public enum FilePreview: Equatable, Sendable {
    case markdown(String)
    case text(String, language: String?)
    case image(URL)
    case unavailable(name: String, size: Int64, type: String, reason: UnavailableReason)
}

public struct FileLoader: Equatable, Sendable {
    public static let maxByteCount = 2 * 1024 * 1024
    public var maxByteCount: Int

    public init(maxByteCount: Int = FileLoader.maxByteCount) {
        self.maxByteCount = maxByteCount
    }

    public func load(url: URL) -> FilePreview {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let type = ext.isEmpty ? "unknown" : ext

        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let size = Int64(values?.fileSize ?? 0)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .unavailable(name: name, size: 0, type: type, reason: .unreadable)
        }

        if size > Int64(maxByteCount) {
            return .unavailable(name: name, size: size, type: type, reason: .tooLarge)
        }

        if Self.imageExtensions.contains(ext) {
            return .image(url.standardizedFileURL)
        }

        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard let text = String(data: data, encoding: .utf8) else {
                return .unavailable(name: name, size: size, type: type, reason: .notText)
            }
            if Self.markdownExtensions.contains(ext) {
                return .markdown(text)
            }
            return .text(text, language: Self.language(for: ext))
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoPermissionError {
                return .unavailable(name: name, size: size, type: type, reason: .permissionDenied)
            }
            if error.domain == NSPOSIXErrorDomain && error.code == Int(EACCES) {
                return .unavailable(name: name, size: size, type: type, reason: .permissionDenied)
            }
            return .unavailable(name: name, size: size, type: type, reason: .unreadable)
        }
    }

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown"]
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "svg"]

    private static func language(for ext: String) -> String? {
        switch ext {
        case "js", "mjs", "cjs", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "go": return "go"
        case "rs": return "rust"
        case "swift": return "swift"
        case "json": return "json"
        case "yml", "yaml": return "yaml"
        case "toml": return "toml"
        case "css": return "css"
        case "html", "htm": return "html"
        case "sh", "bash", "zsh": return "shell"
        default: return nil
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter FileLoaderTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReadMeCore/FileLoader.swift Tests/ReadMeCoreTests/FileLoaderTests.swift
git commit -m "Classify and load files for the read-only preview."
```

---

### Task 4: LinkRouter

**Files:**
- Create: `Sources/ReadMeCore/LinkRouter.swift`
- Test: `Tests/ReadMeCoreTests/LinkRouterTests.swift`

**Interfaces:**
- Consumes: folder URL + current file URL
- Produces:

```swift
public enum LinkDecision: Equatable, Sendable {
    case select(URL)
    case openExternal(URL)
    case ignore
}

public struct LinkRouter: Sendable {
    public var folderURL: URL
    public var currentFileURL: URL
    public init(folderURL: URL, currentFileURL: URL)
    public func decide(href: String) -> LinkDecision
}
```

Rules: `http`/`https` → `openExternal`. `mailto:` and empty href → `ignore`. Relative href resolved against the current file’s directory. If the standardized target exists and its path equals `folderURL` or is prefixed by `folderURL.path + "/"`, → `select`. Missing file, or any path outside the folder (including `../../` escapes) → `ignore`.

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter LinkRouterTests
```

Expected: FAIL because `LinkRouter` does not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

public enum LinkDecision: Equatable, Sendable {
    case select(URL)
    case openExternal(URL)
    case ignore
}

public struct LinkRouter: Sendable {
    public var folderURL: URL
    public var currentFileURL: URL

    public init(folderURL: URL, currentFileURL: URL) {
        self.folderURL = folderURL.standardizedFileURL
        self.currentFileURL = currentFileURL.standardizedFileURL
    }

    public func decide(href: String) -> LinkDecision {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .ignore }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() {
            if scheme == "http" || scheme == "https" {
                return .openExternal(url)
            }
            if scheme != "file" {
                return .ignore
            }
        }

        let base = currentFileURL.deletingLastPathComponent()
        let target = URL(fileURLWithPath: trimmed, relativeTo: base).standardizedFileURL
        guard FileManager.default.fileExists(atPath: target.path) else { return .ignore }
        guard isInsideFolder(target) else { return .ignore }
        return .select(target)
    }

    private func isInsideFolder(_ url: URL) -> Bool {
        let folder = folderURL.path
        let path = url.path
        return path == folder || path.hasPrefix(folder.hasSuffix("/") ? folder : folder + "/")
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter LinkRouterTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReadMeCore/LinkRouter.swift Tests/ReadMeCoreTests/LinkRouterTests.swift
git commit -m "Route markdown links inside the open folder only."
```

---

### Task 5: AppSession and ReaderController

**Files:**
- Create: `Sources/ReadMeCore/AppSession.swift`
- Create: `Sources/ReadMeCore/ReaderController.swift`
- Test: `Tests/ReadMeCoreTests/AppSessionTests.swift`
- Test: `Tests/ReadMeCoreTests/ReaderControllerTests.swift`

**Interfaces:**
- Consumes: `FileLoader.load(url:)`, `LinkRouter.decide(href:)`, `HideRules`
- Produces:

```swift
public enum OpenFailure: Equatable, Sendable {
    case missing
    case notFileOrDirectory
    case folderUnreadable
}

public struct OpenResult: Equatable, Sendable {
    public var folderURL: URL
    public var selectedURL: URL?
}

public struct AppSession: Equatable, Sendable {
    public var folderURL: URL?
    public var selectedURL: URL?
    public var showHidden: Bool
    public init(folderURL: URL? = nil, selectedURL: URL? = nil, showHidden: Bool = false)
    public mutating func open(_ url: URL) -> Result<OpenResult, OpenFailure>
    public mutating func closeFolder()
}

public struct ReaderController: Equatable {
    public var session: AppSession
    public var preview: FilePreview?
    public var openError: OpenFailure?
    public init(session: AppSession = AppSession(), loader: FileLoader = FileLoader())
    public mutating func open(_ url: URL)
    public mutating func closeFolder()
    public mutating func select(_ url: URL?)
    public mutating func setShowHidden(_ show: Bool)
    public mutating func handleLink(_ href: String)
    public func linkDecision(for href: String) -> LinkDecision
}
```

`open` success updates `folderURL` / `selectedURL`. Failure leaves the session unchanged. Directory → select `nil`. File → folder is the parent, selected is the file. `ReaderController.open` maps failure into `openError` and does not change preview on failure. Success clears `openError` and loads preview if a file is selected. `handleLink`: `select` → `select(url)`; `openExternal` is returned via `linkDecision` for the UI to open (controller does not call `NSWorkspace`); `handleLink` only applies `.select` (and ignores the rest). UI calls `linkDecision` then `NSWorkspace` for externals.

- [ ] **Step 1: Write the failing tests**

`Tests/ReadMeCoreTests/AppSessionTests.swift`:

```swift
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
```

`Tests/ReadMeCoreTests/ReaderControllerTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter AppSessionTests
swift test --filter ReaderControllerTests
```

Expected: FAIL because the types do not exist.

- [ ] **Step 3: Write minimal implementation**

`Sources/ReadMeCore/AppSession.swift`:

```swift
import Foundation

public enum OpenFailure: Equatable, Sendable {
    case missing
    case notFileOrDirectory
    case folderUnreadable
}

public struct OpenResult: Equatable, Sendable {
    public var folderURL: URL
    public var selectedURL: URL?
}

public struct AppSession: Equatable, Sendable {
    public var folderURL: URL?
    public var selectedURL: URL?
    public var showHidden: Bool

    public init(folderURL: URL? = nil, selectedURL: URL? = nil, showHidden: Bool = false) {
        self.folderURL = folderURL
        self.selectedURL = selectedURL
        self.showHidden = showHidden
    }

    public mutating func open(_ url: URL) -> Result<OpenResult, OpenFailure> {
        let url = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return .failure(.missing)
        }

        let folder: URL
        let selected: URL?
        if isDirectory.boolValue {
            folder = url
            selected = nil
        } else {
            folder = url.deletingLastPathComponent()
            selected = url
        }

        var reachable: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &reachable), reachable.boolValue else {
            return .failure(.notFileOrDirectory)
        }
        guard FileManager.default.isReadableFile(atPath: folder.path) else {
            return .failure(.folderUnreadable)
        }

        let opened = OpenResult(folderURL: folder, selectedURL: selected)
        folderURL = folder
        selectedURL = selected
        return .success(opened)
    }

    public mutating func closeFolder() {
        folderURL = nil
        selectedURL = nil
    }
}
```

`Sources/ReadMeCore/ReaderController.swift`:

```swift
import Foundation

public struct ReaderController: Equatable {
    public var session: AppSession
    public var preview: FilePreview?
    public var openError: OpenFailure?
    private var loader: FileLoader

    public init(session: AppSession = AppSession(), loader: FileLoader = FileLoader()) {
        self.session = session
        self.loader = loader
    }

    public mutating func open(_ url: URL) {
        switch session.open(url) {
        case .success:
            openError = nil
            reloadPreview()
        case .failure(let error):
            openError = error
        }
    }

    public mutating func closeFolder() {
        session.closeFolder()
        preview = nil
        openError = nil
    }

    public mutating func select(_ url: URL?) {
        session.selectedURL = url
        reloadPreview()
    }

    public mutating func setShowHidden(_ show: Bool) {
        session.showHidden = show
    }

    public mutating func handleLink(_ href: String) {
        if case .select(let url) = linkDecision(for: href) {
            select(url)
        }
    }

    public func linkDecision(for href: String) -> LinkDecision {
        guard let folder = session.folderURL, let current = session.selectedURL else {
            return .ignore
        }
        return LinkRouter(folderURL: folder, currentFileURL: current).decide(href: href)
    }

    private mutating func reloadPreview() {
        guard let selected = session.selectedURL else {
            preview = nil
            return
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: selected.path, isDirectory: &isDirectory), isDirectory.boolValue {
            preview = nil
            return
        }
        preview = loader.load(url: selected)
    }
}
```

`FileLoader` is already `Equatable` from Task 3 (`maxByteCount` only), so `ReaderController` can synthesize `Equatable`.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter AppSessionTests
swift test --filter ReaderControllerTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReadMeCore/AppSession.swift Sources/ReadMeCore/ReaderController.swift Sources/ReadMeCore/FileLoader.swift Tests/ReadMeCoreTests/AppSessionTests.swift Tests/ReadMeCoreTests/ReaderControllerTests.swift
git commit -m "Add session and controller for opening a folder and selecting files."
```

---

### Task 6: SwiftUI window chrome

**Files:**
- Modify: `Sources/ReadMe/ReadMeApp.swift`
- Create: `Sources/ReadMe/ContentView.swift`

**Interfaces:**
- Consumes: `ReaderController`, `OpenFailure`
- Produces: one `WindowGroup`, `NavigationSplitView`, empty-state copy, `⌘O` open folder, Close Folder, Show Hidden, Toggle Sidebar `⌘0`, alert on `openError`

There is no SwiftUI unit host in this package. Guard the controller with a focused test that the empty-state strings stay in code you can grep; do not add a new production type. After UI lands, re-run the full core suite so nothing regressed.

- [ ] **Step 1: Re-run core tests (baseline)**

Run:

```bash
swift test
```

Expected: PASS (all existing tests).

- [ ] **Step 2: Replace the stub app with chrome**

`Sources/ReadMe/ReadMeApp.swift`:

```swift
import SwiftUI

@main
struct ReadMeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        .defaultSize(width: 960, height: 640)
    }
}
```

`Sources/ReadMe/ContentView.swift`:

```swift
import AppKit
import ReadMeCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var reader = ReaderController()
    @State private var isOpening = false

    var body: some View {
        NavigationSplitView {
            if reader.session.folderURL != nil {
                Text("Tree")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyView()
            }
        } detail: {
            if reader.session.folderURL == nil {
                VStack(spacing: 8) {
                    Text("Open a folder")
                        .font(.title2)
                    Text("⌘O or read.me .")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Viewer")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 220, max: 320)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text(reader.session.folderURL?.lastPathComponent ?? "read.me")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Open Folder…") { isOpening = true }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
        .fileImporter(isPresented: $isOpening, allowedContentTypes: [.folder], onCompletion: handleOpenResult)
        .alert("Can’t open", isPresented: Binding(
            get: { reader.openError != nil },
            set: { if !$0 { reader.openError = nil } }
        )) {
            Button("OK", role: .cancel) { reader.openError = nil }
        } message: {
            Text(openErrorMessage)
        }
        .onOpenURL { reader.open($0) }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Folder…") { isOpening = true }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Close Folder") { reader.closeFolder() }
            }
            CommandMenu("View") {
                Toggle("Show Hidden", isOn: Binding(
                    get: { reader.session.showHidden },
                    set: { reader.setShowHidden($0) }
                ))
                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.firstResponder?
                        .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }

    private var openErrorMessage: String {
        switch reader.openError {
        case .missing: return "That path does not exist."
        case .notFileOrDirectory: return "That path is not a file or folder."
        case .folderUnreadable: return "That folder is not readable."
        case nil: return ""
        }
    }

    private func handleOpenResult(_ result: Result<URL, Error>) {
        if case .success(let url) = result {
            reader.open(url)
        }
    }
}
```

Do not add Save or New File commands. The empty `CommandGroup(replacing: .newItem)` removes New.

- [ ] **Step 3: Build the app**

Run:

```bash
swift build --product ReadMe
```

Expected: build succeeds.

- [ ] **Step 4: Run core tests again**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReadMe/ReadMeApp.swift Sources/ReadMe/ContentView.swift
git commit -m "Add the Mac window chrome and open-folder commands."
```

---

### Task 7: File tree sidebar

**Files:**
- Create: `Sources/ReadMe/FileTreeView.swift`
- Modify: `Sources/ReadMe/ContentView.swift` (replace the `"Tree"` placeholder)

**Interfaces:**
- Consumes: `FileTree`, `FileNode`, `ReaderController.session`, `select(_:)`
- Produces: disclosure outline; file click selects; folder click expands/collapses only; SF Symbol by extension; expands ancestors when `selectedURL` is set from outside

- [ ] **Step 1: Add a core test for icon mapping (keep logic out of the view)**

Add `public enum FileIcon` to `Sources/ReadMeCore/FileTree.swift`:

```swift
public enum FileIcon {
    public static func systemName(for node: FileNode) -> String {
        if node.isDirectory { return "folder.fill" }
        switch node.url.pathExtension.lowercased() {
        case "md", "markdown", "mdown": return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "webp", "svg": return "photo"
        case "swift", "js", "ts", "py", "go", "rs": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
}
```

Add to `FileTreeTests.swift`:

```swift
@Test func iconForFolderAndMarkdown() {
    let folder = FileNode(url: FixtureProject.root, name: "SampleProject", isDirectory: true)
    let readme = FileNode(
        url: FixtureProject.root.appendingPathComponent("README.md"),
        name: "README.md",
        isDirectory: false
    )
    #expect(FileIcon.systemName(for: folder) == "folder.fill")
    #expect(FileIcon.systemName(for: readme) == "doc.richtext")
}
```

- [ ] **Step 2: Run the new test to verify it fails**

Run:

```bash
swift test --filter FileTreeTests/iconForFolderAndMarkdown
```

Expected: FAIL until `FileIcon` exists.

- [ ] **Step 3: Implement FileIcon (code in Step 1) and FileTreeView**

`Sources/ReadMe/FileTreeView.swift` — use recursive `DisclosureGroup` so a folder click expands/collapses only and never becomes the selected file:

```swift
import ReadMeCore
import SwiftUI

struct FileTreeView: View {
    let root: URL
    let showHidden: Bool
    @Binding var selectedURL: URL?
    @State private var expanded: Set<URL> = []

    var body: some View {
        let tree = FileTree(root: root, rules: HideRules(showHidden: showHidden))
        List {
            ForEach(tree.children(of: root)) { node in
                FileOutline(node: node, tree: tree, expanded: $expanded, selectedURL: $selectedURL)
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            expanded.insert(root)
            if let selectedURL {
                for url in tree.expandingAncestors(to: selectedURL) {
                    expanded.insert(url)
                }
            }
        }
        .onChange(of: selectedURL) { _, newValue in
            guard let newValue else { return }
            for url in tree.expandingAncestors(to: newValue) {
                expanded.insert(url)
            }
        }
    }
}

struct FileOutline: View {
    let node: FileNode
    let tree: FileTree
    @Binding var expanded: Set<URL>
    @Binding var selectedURL: URL?

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: Binding(
                get: { expanded.contains(node.url) },
                set: { isOn in
                    if isOn { expanded.insert(node.url) } else { expanded.remove(node.url) }
                }
            )) {
                ForEach(tree.children(of: node.url)) { child in
                    FileOutline(node: child, tree: tree, expanded: $expanded, selectedURL: $selectedURL)
                }
            } label: {
                Label(node.name, systemImage: FileIcon.systemName(for: node))
            }
        } else {
            Label(node.name, systemImage: FileIcon.systemName(for: node))
                .lineLimit(1)
                .foregroundStyle(selectedURL == node.url ? Color.accentColor : Color.primary)
                .onTapGesture { selectedURL = node.url }
        }
    }
}
```

Wire `ContentView` sidebar:

```swift
if let folder = reader.session.folderURL {
    FileTreeView(
        root: folder,
        showHidden: reader.session.showHidden,
        selectedURL: Binding(
            get: { reader.session.selectedURL },
            set: { reader.select($0) }
        )
    )
} else {
    EmptyView()
}
```

- [ ] **Step 4: Run tests and build**

Run:

```bash
swift test
swift build --product ReadMe
```

Expected: PASS and build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReadMeCore/FileTree.swift Sources/ReadMe/FileTreeView.swift Sources/ReadMe/ContentView.swift Tests/ReadMeCoreTests/FileTreeTests.swift
git commit -m "Show a lazy sidebar tree for the open folder."
```

---

### Task 8: Viewer switch, image, unavailable card

**Files:**
- Create: `Sources/ReadMe/ViewerView.swift`
- Create: `Sources/ReadMe/ImageDocumentView.swift`
- Create: `Sources/ReadMe/UnavailableCard.swift`
- Modify: `Sources/ReadMe/ContentView.swift` (replace the `"Viewer"` placeholder)
- Test: add cases to `FileLoaderTests` only if SVG/size-type strings are still uncovered — they are already covered. Add a reason-copy function in core so the card does not invent strings.

**Interfaces:**
- Consumes: `FilePreview`, `UnavailableReason`
- Produces: `public enum UnavailableCopy` in `FileLoader.swift` with `public static func message(for reason: UnavailableReason) -> String` returning exactly: `"binary"`, `"too large to preview"`, `"not text"`, `"permission denied"`, `"unreadable"`

- [ ] **Step 1: Write the failing test**

Add to `FileLoaderTests.swift`:

```swift
@Test func unavailableCopyMatchesSpec() {
    #expect(UnavailableCopy.message(for: .binary) == "binary")
    #expect(UnavailableCopy.message(for: .tooLarge) == "too large to preview")
    #expect(UnavailableCopy.message(for: .notText) == "not text")
    #expect(UnavailableCopy.message(for: .permissionDenied) == "permission denied")
    #expect(UnavailableCopy.message(for: .unreadable) == "unreadable")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter FileLoaderTests/unavailableCopyMatchesSpec
```

Expected: FAIL because `UnavailableCopy` does not exist.

- [ ] **Step 3: Implement copy + views**

Add to `FileLoader.swift`:

```swift
public enum UnavailableCopy {
    public static func message(for reason: UnavailableReason) -> String {
        switch reason {
        case .binary: return "binary"
        case .tooLarge: return "too large to preview"
        case .notText: return "not text"
        case .permissionDenied: return "permission denied"
        case .unreadable: return "unreadable"
        }
    }
}
```

`Sources/ReadMe/UnavailableCard.swift`:

```swift
import ReadMeCore
import SwiftUI

struct UnavailableCard: View {
    let name: String
    let size: Int64
    let type: String
    let reason: UnavailableReason

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.title2)
            Text(byteCount).foregroundStyle(.secondary)
            Text(type).foregroundStyle(.secondary)
            Text(UnavailableCopy.message(for: reason))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var byteCount: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
```

`Sources/ReadMe/ImageDocumentView.swift`:

```swift
import AppKit
import SwiftUI

struct ImageDocumentView: View {
    let url: URL

    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            UnavailableCard(
                name: url.lastPathComponent,
                size: (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0,
                type: url.pathExtension,
                reason: .unreadable
            )
        }
    }
}
```

`Sources/ReadMe/ViewerView.swift`:

```swift
import ReadMeCore
import SwiftUI

struct ViewerView: View {
    let preview: FilePreview?
    let onLink: (String) -> Void

    var body: some View {
        switch preview {
        case .markdown(let text):
            MarkdownDocumentView(text: text, onLink: onLink)
        case .text(let text, let language):
            CodeDocumentView(text: text, language: language)
        case .image(let url):
            ImageDocumentView(url: url)
        case .unavailable(let name, let size, let type, let reason):
            UnavailableCard(name: name, size: size, type: type, reason: reason)
        case nil:
            Text("Select a file")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
```

Temporarily stub the two document views so the target compiles (replaced in Tasks 9 and 10):

`Sources/ReadMe/CodeDocumentView.swift`:

```swift
import SwiftUI

struct CodeDocumentView: View {
    let text: String
    let language: String?

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
    }
}
```

`Sources/ReadMe/MarkdownDocumentView.swift`:

```swift
import SwiftUI

struct MarkdownDocumentView: View {
    let text: String
    let onLink: (String) -> Void

    var body: some View {
        ScrollView {
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
    }
}
```

In `ContentView` detail, when a folder is open:

```swift
ViewerView(preview: reader.preview, onLink: { reader.handleLink($0) })
```

- [ ] **Step 4: Run tests and build**

Run:

```bash
swift test
swift build --product ReadMe
```

Expected: PASS and build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReadMeCore/FileLoader.swift Sources/ReadMe/ViewerView.swift Sources/ReadMe/ImageDocumentView.swift Sources/ReadMe/UnavailableCard.swift Sources/ReadMe/CodeDocumentView.swift Sources/ReadMe/MarkdownDocumentView.swift Sources/ReadMe/ContentView.swift Tests/ReadMeCoreTests/FileLoaderTests.swift
git commit -m "Switch the content pane between image, card, and text stubs."
```

---

### Task 9: Code view with line numbers and Splash

**Files:**
- Create: `Sources/ReadMe/Highlighting.swift`
- Modify: `Sources/ReadMe/CodeDocumentView.swift`

**Interfaces:**
- Consumes: `FilePreview.text(String, language: String?)`
- Produces: `enum Highlighter` with `static func attributed(_ text: String, language: String?, dark: Bool) -> AttributedString`. Unknown language or missing grammar → plain monospaced text. Line numbers in the view, wrap on, text selectable, read-only.

Splash ships a real Swift grammar. Other v1 languages use a `KeywordGrammar` (keywords, comments, strings, numbers) so we do not pull in a JS engine.

- [ ] **Step 1: Confirm language tags already fail/pass in core**

Run:

```bash
swift test --filter FileLoaderTests/classifiesSwiftAsText
```

Expected: PASS. Language strings are already covered. Highlighting stays in the app target; this task’s automated check is `swift build --product ReadMe` plus `swift test`.

- [ ] **Step 2: Implement highlighter**

`Sources/ReadMe/Highlighting.swift`:

```swift
import Splash
import SwiftUI

enum Highlighter {
    static func attributed(_ text: String, language: String?, dark: Bool) -> AttributedString {
        let font = Splash.Font(size: 13)
        let theme = dark ? Theme.midnight(withFont: font) : Theme.sunset(withFont: font)
        let format = AttributedStringOutputFormat(theme: theme)
        let highlighter = SyntaxHighlighter(format: format, grammar: grammar(for: language))
        let output = highlighter.highlight(text)
        return AttributedString(output)
    }

    private static func grammar(for language: String?) -> Grammar {
        switch language {
        case "swift": return SwiftGrammar()
        case "javascript", "typescript":
            return KeywordGrammar(keywords: [
                "async", "await", "break", "case", "catch", "class", "const", "continue",
                "debugger", "default", "delete", "do", "else", "export", "extends", "false",
                "finally", "for", "function", "if", "import", "in", "instanceof", "let",
                "new", "null", "return", "static", "super", "switch", "this", "throw",
                "true", "try", "typeof", "var", "void", "while", "with", "yield",
            ], lineComment: "//", blockComment: ("/*", "*/"))
        case "python":
            return KeywordGrammar(keywords: [
                "and", "as", "assert", "async", "await", "break", "class", "continue",
                "def", "del", "elif", "else", "except", "false", "finally", "for",
                "from", "global", "if", "import", "in", "is", "lambda", "none", "nonlocal",
                "not", "or", "pass", "raise", "return", "true", "try", "while", "with", "yield",
            ], lineComment: "#", blockComment: ("\"\"\"", "\"\"\""))
        case "go":
            return KeywordGrammar(keywords: [
                "break", "case", "chan", "const", "continue", "default", "defer", "else",
                "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
                "map", "package", "range", "return", "select", "struct", "switch", "type", "var",
            ], lineComment: "//", blockComment: ("/*", "*/"))
        case "rust":
            return KeywordGrammar(keywords: [
                "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else",
                "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop",
                "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self",
                "static", "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while",
            ], lineComment: "//", blockComment: ("/*", "*/"))
        case "json":
            return KeywordGrammar(keywords: ["true", "false", "null"], lineComment: nil, blockComment: nil)
        case "yaml":
            return KeywordGrammar(keywords: ["true", "false", "null", "yes", "no"], lineComment: "#", blockComment: nil)
        case "toml":
            return KeywordGrammar(keywords: ["true", "false"], lineComment: "#", blockComment: nil)
        case "css":
            return KeywordGrammar(keywords: [
                "align-items", "block", "color", "display", "flex", "font", "grid", "height",
                "margin", "padding", "position", "width",
            ], lineComment: nil, blockComment: ("/*", "*/"))
        case "html":
            return KeywordGrammar(keywords: [
                "div", "span", "html", "head", "body", "script", "style", "link", "meta",
                "title", "a", "p", "ul", "li", "h1", "h2", "h3",
            ], lineComment: nil, blockComment: ("<!--", "-->"))
        case "shell":
            return KeywordGrammar(keywords: [
                "if", "then", "else", "fi", "for", "do", "done", "case", "esac", "while",
                "function", "return", "in",
            ], lineComment: "#", blockComment: nil)
        default:
            return KeywordGrammar(keywords: [], lineComment: nil, blockComment: nil)
        }
    }
}

struct KeywordGrammar: Grammar {
    let keywords: Set<String>
    let lineComment: String?
    let blockComment: (String, String)?

    var delimiters: CharacterSet {
        var set = CharacterSet.alphanumerics.inverted
        set.remove("_")
        set.remove("\"")
        set.remove("'")
        set.remove("#")
        return set
    }

    var syntaxRules: [SyntaxRule] {
        var rules: [SyntaxRule] = [
            KeywordRule(keywords: keywords),
            StringRule(),
            NumberRule(),
        ]
        if let lineComment {
            rules.append(LineCommentRule(prefix: lineComment))
        }
        if let blockComment {
            rules.append(BlockCommentRule(open: blockComment.0, close: blockComment.1))
        }
        return rules
    }
}

struct KeywordRule: SyntaxRule {
    let keywords: Set<String>
    var tokenType: TokenType { .keyword }
    func matches(_ segment: Segment) -> Bool {
        keywords.contains(segment.tokens.current)
    }
}

struct StringRule: SyntaxRule {
    var tokenType: TokenType { .string }
    func matches(_ segment: Segment) -> Bool {
        segment.tokens.current.hasPrefix("\"") || segment.tokens.current.hasPrefix("'")
    }
}

struct NumberRule: SyntaxRule {
    var tokenType: TokenType { .number }
    func matches(_ segment: Segment) -> Bool {
        segment.tokens.current.contains(where: \.isNumber)
            && segment.tokens.current.allSatisfy { $0.isNumber || $0 == "." }
    }
}

struct LineCommentRule: SyntaxRule {
    let prefix: String
    var tokenType: TokenType { .comment }
    func matches(_ segment: Segment) -> Bool {
        segment.tokens.current.hasPrefix(prefix)
    }
}

struct BlockCommentRule: SyntaxRule {
    let open: String
    let close: String
    var tokenType: TokenType { .comment }
    func matches(_ segment: Segment) -> Bool {
        segment.tokens.current.contains(open) || segment.tokens.current.contains(close)
    }
}
```

Splash 0.16 `SyntaxRule` is `tokenType` + `matches(_ segment: Segment) -> Bool`. `SyntaxHighlighter(format:grammar:)` takes that `Grammar`. `AttributedStringOutputFormat.highlight` returns `NSAttributedString`; wrap it with `AttributedString(...)`. Do not add a JavaScript engine.

Replace `CodeDocumentView` with a wrap-on, selectable, line-numbered pane:

```swift
import SwiftUI

struct CodeDocumentView: View {
    let text: String
    let language: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let highlighted = Highlighter.attributed(text, language: language, dark: colorScheme == .dark)
        ScrollView {
            HStack(alignment: .top, spacing: 12) {
                Text(lineNumbers(for: lines.count))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                Text(highlighted)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
    }

    private func lineNumbers(for count: Int) -> String {
        (1...max(count, 1)).map(String.init).joined(separator: "\n")
    }
}
```

Wrap stays on because the scroll view is vertical only.

- [ ] **Step 3: Build**

Run:

```bash
swift build --product ReadMe
```

Expected: build succeeds.

- [ ] **Step 4: Run tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReadMe/Highlighting.swift Sources/ReadMe/CodeDocumentView.swift
git commit -m "Highlight source with Splash and show line numbers."
```

---

### Task 10: Native markdown, images, and links

**Files:**
- Modify: `Sources/ReadMe/MarkdownDocumentView.swift`
- Modify: `Sources/ReadMe/ContentView.swift` (pass current file URL + folder into the markdown view)
- Modify: `Sources/ReadMe/ViewerView.swift` if the markdown view needs more than `text` + `onLink`

**Interfaces:**
- Consumes: `LinkRouter` / `ReaderController.handleLink`, `ReaderController.linkDecision(for:)`, MarkdownUI
- Produces: selectable rendered GFM (headings, lists, quotes, tables, inline/fenced code). Relative images load only when `LinkRouter.decide` would `select` that path (file exists inside folder). Failed image → a placeholder `Image(systemName: "photo")`. `http`/`https` → `NSWorkspace.shared.open`. Other decisions → `handleLink`.

- [ ] **Step 1: Extend ViewerView to pass routing context**

Change signatures to:

```swift
struct ViewerView: View {
    let preview: FilePreview?
    let folderURL: URL?
    let currentFileURL: URL?
    let onLink: (String) -> Void
}

struct MarkdownDocumentView: View {
    let text: String
    let folderURL: URL
    let currentFileURL: URL
    let onLink: (String) -> Void
}
```

From `ContentView`:

```swift
ViewerView(
    preview: reader.preview,
    folderURL: reader.session.folderURL,
    currentFileURL: reader.session.selectedURL,
    onLink: { href in
        let decision = reader.linkDecision(for: href)
        if case .openExternal(let url) = decision {
            NSWorkspace.shared.open(url)
        } else {
            reader.handleLink(href)
        }
    }
)
```

- [ ] **Step 2: Implement MarkdownDocumentView with MarkdownUI**

```swift
import AppKit
import MarkdownUI
import ReadMeCore
import SwiftUI

struct MarkdownDocumentView: View {
    let text: String
    let folderURL: URL
    let currentFileURL: URL
    let onLink: (String) -> Void

    var body: some View {
        ScrollView {
            Markdown(text)
                .markdownTheme(.basic)
                .textSelection(.enabled)
                .markdownImageProvider(ProjectImageProvider(
                    folderURL: folderURL,
                    currentFileURL: currentFileURL
                ))
                .environment(\.openURL, OpenURLAction { url in
                    onLink(url.absoluteString.hasPrefix("file:")
                           ? relativeHREF(from: url)
                           : (url.scheme == nil ? url.path : url.absoluteString))
                    return .handled
                })
                .frame(maxWidth: 800, alignment: .leading)
                .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func relativeHREF(from url: URL) -> String {
        url.path
    }
}

struct ProjectImageProvider: ImageProvider {
    let folderURL: URL
    let currentFileURL: URL

    @ViewBuilder
    func makeImage(url: URL?) -> some View {
        ProjectImage(folderURL: folderURL, currentFileURL: currentFileURL, href: href(from: url))
    }

    private func href(from url: URL?) -> String {
        guard let url else { return "" }
        if url.scheme == nil { return url.relativeString }
        if url.isFileURL { return url.path }
        return url.absoluteString
    }
}

private struct ProjectImage: View {
    let folderURL: URL
    let currentFileURL: URL
    let href: String

    var body: some View {
        switch LinkRouter(folderURL: folderURL, currentFileURL: currentFileURL).decide(href: href) {
        case .select(let fileURL):
            if let image = NSImage(contentsOf: fileURL) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        default:
            Image(systemName: "photo").foregroundStyle(.secondary)
        }
    }
}
```

Relative markdown links often arrive as `URL(string: "docs/guide.md")` with no scheme. In `openURL`, if `url.scheme == nil`, pass `url.relativeString` or `url.path` into `onLink` so `LinkRouter` sees `docs/guide.md`, not a file URL from the process CWD.

Add a unit test for that string form — already covered by `LinkRouterTests.relativeDocSelects` using `./docs/guide.md`. Also add:

```swift
@Test func hrefWithoutDotSlashSelects() {
    #expect(
        router.decide(href: "docs/guide.md") ==
        .select(FixtureProject.root.appendingPathComponent("docs/guide.md").standardizedFileURL)
    )
}
```

- [ ] **Step 3: Run the new router test to verify it fails, then confirm implementation already passes**

Run:

```bash
swift test --filter LinkRouterTests/hrefWithoutDotSlashSelects
```

If it fails, `LinkRouter.decide` already uses `URL(fileURLWithPath:relativeTo:)`, which should accept `docs/guide.md`. Fix only if this fails.

- [ ] **Step 4: Build and test**

Run:

```bash
swift test
swift build --product ReadMe
```

Expected: PASS and build succeeds. `Theme.basic` uses environment colors, so macOS light/dark just works. Do not add a settings window.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReadMe/MarkdownDocumentView.swift Sources/ReadMe/ViewerView.swift Sources/ReadMe/ContentView.swift Tests/ReadMeCoreTests/LinkRouterTests.swift
git commit -m "Render markdown natively with in-folder images and links."
```

---

### Task 11: CLI `read.me`

**Files:**
- Modify: `Sources/ReadMeCLI/main.swift`
- Create: `Tests/ReadMeCoreTests/CLIPathTests.swift` — keep path resolution in core so the CLI stays thin

**Interfaces:**
- Consumes: `AppSession.open` is not required in the CLI; the CLI only resolves the first argument
- Produces: `public enum CLIArgs` in `AppSession.swift` (path helper, not session state):

```swift
public enum CLIArgs {
    public static func resolvedPath(from arguments: [String], cwd: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> URL?
}
```

`arguments` is `CommandLine.arguments`. Index 0 is the tool name. No extra path → `nil` (launch empty). First path after argv0 → absolute standardized URL (expand `~`, resolve relative against `cwd`). Ignore arguments after the first path.

CLI then: if `nil`, `NSWorkspace.shared.openApplication(at:appURL)`. Else `NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration:)`. Bundle ID `me.read.app`. If the app URL cannot be found, print `read.me app not found (me.read.app). Build the app bundle first.` to stderr and `exit(1)`.

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter CLIPathTests
```

Expected: FAIL because `CLIArgs` does not exist.

- [ ] **Step 3: Implement CLIArgs and main**

Add to `AppSession.swift`:

```swift
public enum CLIArgs {
    public static func resolvedPath(
        from arguments: [String],
        cwd: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> URL? {
        guard arguments.count >= 2 else { return nil }
        let raw = arguments[1]
        if raw == "~" || raw.hasPrefix("~/") {
            let expanded = (raw as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded).standardizedFileURL
        }
        if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw).standardizedFileURL
        }
        return cwd.appendingPathComponent(raw).standardizedFileURL
    }
}
```

`Sources/ReadMeCLI/main.swift`:

```swift
import AppKit
import Foundation
import ReadMeCore

let bundleID = "me.read.app"
guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
    fputs("read.me app not found (me.read.app). Build the app bundle first.\n", stderr)
    exit(1)
}

let config = NSWorkspace.OpenConfiguration()
let group = DispatchGroup()
group.enter()

if let path = CLIArgs.resolvedPath(from: CommandLine.arguments) {
    NSWorkspace.shared.open([path], withApplicationAt: appURL, configuration: config) { _, error in
        if let error {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
        group.leave()
    }
} else {
    NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
        if let error {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
        group.leave()
    }
}

_ = group.wait(timeout: .now() + 10)
```

- [ ] **Step 4: Run tests and build the CLI**

Run:

```bash
swift test --filter CLIPathTests
swift build --product read.me
```

Expected: PASS and build succeeds. Running `./.build/debug/read.me` before the bundle exists should exit 1 with the not-found message.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReadMeCore/AppSession.swift Sources/ReadMeCLI/main.swift Tests/ReadMeCoreTests/CLIPathTests.swift
git commit -m "Add a read.me CLI that opens the Mac app on a path."
```

---

### Task 12: AppDelegate, Info.plist, bundle script, single instance

**Files:**
- Create: `Sources/ReadMe/ReaderStore.swift`
- Create: `Sources/ReadMe/AppDelegate.swift`
- Modify: `Sources/ReadMe/ReadMeApp.swift`
- Modify: `Sources/ReadMe/ContentView.swift`
- Create: `Info.plist`
- Create: `scripts/bundle-app.sh`

**Interfaces:**
- Consumes: `ReaderController.open`
- Produces: dock / Finder folder drop and CLI `open` URLs reach the same `ReaderController`. `LSMultipleInstancesProhibited` = true. Second `read.me ~/other` activates and switches folder.

- [ ] **Step 1: Write AppDelegate and rewire ownership**

`Sources/ReadMe/ReaderStore.swift`:

```swift
import ReadMeCore
import SwiftUI

@MainActor
final class ReaderStore: ObservableObject {
    static let shared = ReaderStore()

    @Published var reader = ReaderController()

    private init() {}

    func open(_ url: URL) {
        update { controller in
            controller.open(url)
        }
    }

    func update(_ body: (inout ReaderController) -> Void) {
        body(&reader)
    }
}
```

`Sources/ReadMe/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ReaderStore.shared

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            store.open(url)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        store.open(URL(fileURLWithPath: filename))
        return true
    }
}
```

`Sources/ReadMe/ReadMeApp.swift`:

```swift
import SwiftUI

@main
struct ReadMeApp: App {
    @StateObject private var store = ReaderStore.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        .defaultSize(width: 960, height: 640)
        .handlesExternalEvents(matching: Set(["*"]))
    }
}
```

In `ContentView`, replace `@State private var reader = ReaderController()` with `@EnvironmentObject private var store: ReaderStore`. Mutate through `store.update { controller in ... }`. Read `store.reader` for `session`, `preview`, and `openError`. Example open:

```swift
store.update { controller in
    controller.open(url)
}
```

- [ ] **Step 2: Write Info.plist and the bundle script**

`Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>read.me</string>
    <key>CFBundleExecutable</key>
    <string>ReadMe</string>
    <key>CFBundleIconFile</key>
    <string></string>
    <key>CFBundleIdentifier</key>
    <string>me.read.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>read.me</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSMultipleInstancesProhibited</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Folder</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.folder</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Text</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.item</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

`scripts/bundle-app.sh`:

```bash
#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product ReadMe
swift build -c release --product read.me
APP="dist/read.me.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ReadMe "$APP/Contents/MacOS/ReadMe"
cp Info.plist "$APP/Contents/Info.plist"
cp .build/release/read.me "$APP/Contents/MacOS/read.me"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
echo "Built $APP"
echo "CLI: $APP/Contents/MacOS/read.me"
echo "Open: open \"$APP\""
```

Make it executable: `chmod +x scripts/bundle-app.sh`

- [ ] **Step 3: Build the bundle and register it**

Run:

```bash
./scripts/bundle-app.sh
```

Expected: `dist/read.me.app` exists and `lsregister` runs without error.

- [ ] **Step 4: Manual check (spec v1 gate)**

Run these in order on your Mac:

```bash
open dist/read.me.app
dist/read.me.app/Contents/MacOS/read.me Fixtures/SampleProject
dist/read.me.app/Contents/MacOS/read.me /tmp
```

Confirm:

1. Cold launch of `open dist/read.me.app` shows the empty state in about one second.
2. `⌘O` opens a folder; the tree hides `node_modules` / `.git`; Show Hidden reveals `.env` only.
3. Click `README.md` → rendered GFM, image `dot.png` visible, click `docs/guide.md` → that file.
4. Click `src/main.swift` → highlighted source + line numbers.
5. Click `assets/dot.png` → image. Click `notes.bin` → card (“not text” or “binary”).
6. External `https` link in markdown opens Safari. A missing relative link does nothing.
7. Second CLI call on `/tmp` **replaces** the folder in the same window (no second instance).
8. Light and dark (System Settings) both stay readable.
9. Copy works on markdown and code. There is no Save / no editing.

If a step fails, fix that code and re-run `swift test` plus the failed manual step. Do not add features to pass the list.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReadMe/AppDelegate.swift Sources/ReadMe/ReadMeApp.swift Sources/ReadMe/ReaderStore.swift Sources/ReadMe/ContentView.swift Info.plist scripts/bundle-app.sh
git commit -m "Bundle a single-instance Mac app the CLI can open."
```
