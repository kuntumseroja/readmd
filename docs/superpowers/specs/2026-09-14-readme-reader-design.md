# read.me — read-only project viewer

A Mac-only SwiftUI app that opens a folder and lets you read files. Markdown renders as a document. Source renders as highlighted, read-only code. Nothing is editable.

This is the light window you keep beside an editor: folder tree, click a file, read, next file.

## Goal

Open a project in about a second, use little memory, and feel closer to Preview than to VS Code. No Chromium, no Electron, no Node runtime.

**Success for v1**

- Cold launch to a usable window in about one second on a typical Mac.
- Open a folder via `File → Open Folder…` (`⌘O`) or `read.me /path`.
- Click `README.md` and see rendered GFM. Click a `.swift` (or similar) and see highlighted source with line numbers.
- Tree stays usable on real repos because junk folders are hidden and children load lazily.

## Non-goals (v1)

Search (in-file or project), tabs, recents, reopen-last-folder, multi-window, git, outline, minimap, command palette, mermaid, math, hex view, settings window, custom themes, file-change watching, App Store / sandbox, Windows, Linux, CI.

## Users and job

You already have an editor. You open `read.me` on a folder when you want to skim the project without the weight or the risk of typing.

## Platform

- macOS 14.0+
- Native SwiftUI app, non-sandboxed (developer utility). Sandbox would block `read.me .` on arbitrary folders.
- Single process, single window. Opening another folder replaces the current one.
- Appearance follows macOS light/dark. No extra theme pack.

Display name: **read.me**. Bundle ID: `me.read.app`. CLI name: `read.me`.

## Architecture

Five units. Each has one job and a small surface.

| Unit | Does | Depends on |
| --- | --- | --- |
| `AppSession` | Holds `folderURL: URL?`. Open dialog, dock drop, and CLI set it. A second open **replaces** the folder. | Foundation |
| `FileTree` | Lazy outline of that folder, with hide rules applied while building children. | `folderURL` |
| `FileLoader` | On selection, classify and read. One file in memory at a time. | selected `URL` |
| `Viewer` | Renders exactly one of: markdown, code, image, unavailable card. | `Preview` from the loader |
| `LinkRouter` | Resolves markdown link clicks: in-folder file → select it; `http(s)` → browser; anything else → no-op. | `AppSession` |

No database, no search index, no content cache. The tree does not keep children of collapsed folders warm beyond what SwiftUI has on screen.

CLI is a thin helper: resolve the path to an absolute URL, hand it to the running app (or launch it), exit. The app is single-instance. A second `read.me ~/other` activates the window and switches folder.

If the user passes a file path, open its parent folder and select that file. If CLI is invoked with no arguments, launch the app empty. Extra arguments after the first path are ignored.

## UI

VS Code *layout*, Mac *materials*: traffic lights, native sidebar, system fonts, no editor skin.

- `NavigationSplitView`. Sidebar about 220pt. Standard sidebar toggle and `⌘0`.
- Toolbar: folder name and **Open Folder…** (`⌘O`) only.
- Menus: File (Open Folder, Close Folder), View (Show Hidden, Toggle Sidebar), plus stock Edit/App menus so Copy works. No Save, no New File. **Close Folder** sets `folderURL` to nil and returns to the empty state.
- Empty state: no tree. Content pane says to open a folder (`⌘O` or `read.me .`).
- Sidebar: disclosure outline, SF Symbol icons by extension. Click a file to load. Click a folder to expand or collapse only.
- Content pane is one of four views, never stacked. No tab strip, no status bar.

### MarkdownView

Native SwiftUI rendering with MarkdownUI and Apple’s swift-markdown. No WKWebView. GFM subset:

- headings, lists, block quotes, tables
- inline and fenced code
- images resolved relative to the current `.md` file, only if the image path stays inside `folderURL`
- relative file links go through `LinkRouter`
- `http`/`https` open in the default browser via `NSWorkspace`

Text is selectable. Failed inline images show a placeholder, not a crash.

### CodeView

Read-only, selectable, line numbers, wrap on (no wrap toggle). Splash for syntax color. No JavaScript engine.

Languages in v1: JavaScript, TypeScript, Python, Go, Rust, Swift, JSON, YAML, TOML, CSS, HTML, shell. Unknown UTF-8 text: plain + line numbers.

### ImageView

Preview `png`, `jpg`/`jpeg`, `gif`, `webp`. For `svg`, try `NSImage(contentsOf:)`; if that yields an image, show it, otherwise the unavailable card.

### UnavailableCard

Filename, size, type, and one line of why: binary, too large, not text, permission denied, or unreadable.

## Hide rules

Applied when listing a directory, not as a later filter.

**Always hidden (even with Show Hidden):**

`.git`, `node_modules`, `dist`, `build`, `.next`, `target`, `.build`, `DerivedData`, `.venv`, `venv`, `__pycache__`, `.turbo`, `.cache`, `coverage`, `out`

**Hidden unless View → Show Hidden:** any name that starts with `.`

Show Hidden reveals dotfiles and dot-directories that are not on the always-hidden list. It does not reveal `node_modules` or `.git`.

## File classification

`FileLoader` runs off the main thread. It looks at extension/UTI and a small sniff of bytes.

| Result | When |
| --- | --- |
| `markdown` | `.md`, `.markdown`, `.mdown` |
| `image` | `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg` |
| `text` | UTF-8 text that is not markdown (including the highlight languages above and any other valid UTF-8) |
| `binary` | not valid UTF-8, or a known binary type |

Hard cap: if the file is larger than **2 MB**, do not read it. Show the unavailable card (“too large to preview”).

Invalid UTF-8 → unavailable card (“not text”). Permission errors on a selected file → card (“permission denied”). One `Preview` value is published back to the main thread; the previous preview is dropped.

## Link routing

Resolve relative links against the current file URL.

- Target exists and is inside `folderURL` → change selection. Expand the tree enough to show that row.
- `http`/`https` → `NSWorkspace.open`
- `mailto:`, missing file, or any path that resolves outside `folderURL` (including `../../` escapes) → no navigation, no alert
- If the default browser cannot open an external URL → ignore

## Errors

Alerts only when **opening a folder** fails (path missing, not a file/directory, folder unreadable). Keep the previous session.

Everything about a **selected file** is the card or a quiet no-op. No toast stack, no error-log UI.

Unreadable subfolders appear as rows; expanding them yields no children and no modal.

A single directory with thousands of entries is still listed. The tree does not recurse until the user expands.

## Dependencies (intended)

- SwiftUI + AppKit only for Open panel, dock file open, `NSWorkspace`, and single-instance URL delivery
- [swift-markdown](https://github.com/swiftlang/swift-markdown) + [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)
- [Splash](https://github.com/JohnSundell/Splash)

No WKWebView. No Chromium. No Electron. No Tauri.

## Testing

Fixture folder in-repo: `Fixtures/SampleProject/` with markdown, images, relative links, dummy `.git` and `node_modules`, a small binary, and a valid UTF-8 file. The >2 MB file is generated in the test, not stored.

**Automated (Swift Testing)**

- `FileTree`: junk and dotfiles hidden; Show Hidden reveals dotfiles but not junk; collapsed junk directories are never read
- `FileLoader`: classifies markdown / Swift / PNG / binary; 2 MB+ → too large; invalid UTF-8 → not text
- `LinkRouter`: `./doc.md` and in-folder `../doc.md` select; path escape and missing files no-op; `https://…` marked external

**Manual, once, before calling v1 done**

- Open via `⌘O` and via `read.me` on the fixture
- Second `read.me` on another folder switches the window
- README renders; `.swift` highlights with line numbers; PNG shows; binary shows the card
- Light and dark
- Cold launch feels about one second

No screenshot suite, no GitHub Actions, no performance harness in v1.

## Implementation notes

- Xcode project at the repo root: app target, `read.me` command-line target, and a test target. The CLI resolves the path to an absolute file URL and asks `NSWorkspace` to open `me.read.app` with that URL. The app accepts the path on launch and again while running (single instance).
- Read-only means the UI never writes project files. Copy from the reader is allowed.
- If a file on disk changes while it is open, v1 does nothing. Click the file again to reload.

## Open decisions (closed)

| Question | Decision |
| --- | --- |
| Job | Fast project browse beside an editor |
| Form | Desktop Mac app |
| Markdown | Rendered GFM; code is highlighted source |
| v1 features | Tree + click + read only |
| Tree filter | Fixed junk list + hidden dotfiles |
| Launch | Open dialog + CLI |
| Markdown extras | Images + in-app relative links |
| Feel | VS Code layout, Mac materials |
| Non-text | Images preview; else a card |
| Light | Instant, tiny, no Chromium |
| Stack | Native SwiftUI end-to-end |
| Windows | One; replace folder |
| Watcher | None |
