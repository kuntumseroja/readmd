# read.me

A Mac app that opens a folder so you can **read** the project — not edit it.

Markdown renders as a document. Source shows as highlighted, read-only code. Images preview in place. There is no save, no new file, and no Chromium.

**v1.0** · macOS 14+ · Apple Silicon and Intel · bundle id `me.read.app`

---

## What this project is

`read.me` is a small native SwiftUI viewer. You point it at a repo, get a sidebar tree, and click files.

| You click | You see |
| --- | --- |
| `.md` / `.markdown` / `.mdown` | Rendered GitHub-flavored markdown |
| Source (Swift, JS/TS, Python, Go, Rust, JSON, YAML, …) | Highlighted text with line numbers |
| `png`, `jpg`, `gif`, `webp`, `svg` | Image preview |
| Binary, >2 MB, or unreadable | A card with the name, size, and why |

One window. One folder at a time. Opening another folder replaces the current one. The app never writes project files; copy is allowed.

It is not an editor, not VS Code, and not a browser. No Electron, no Node, no WKWebView.

---

## The idea

You already have an editor. You still need a light window beside it: open the folder, skim the README, jump a relative link, look at a screenshot, move on.

Editors are heavy and they let you type. Preview is for one file. `read.me` is the middle: **fast project browse, read-only**.

That is why junk folders stay hidden (`.git`, `node_modules`, `dist`, …), why the tree loads lazily, and why a second `read.me ~/other` just switches the same window.

v1 does not search, tab, watch the disk, or talk to git. If you want to change a file, use your editor.

---

## How to install

You do not need Xcode to run the app. Use one of the packages (after a build they are in `dist/`):

| File | What to do |
| --- | --- |
| `read.me-1.0.pkg` | Double-click Installer. Puts the app in **Applications** and adds the `read.me` command. |
| `read.me-1.0.dmg` | Open the disk. Drag **read.me** onto **Applications**. |
| `read.me-1.0.zip` | Unzip. Move `read.me.app` into Applications. |

Needs **macOS 14 or later**.

### First open

The app is ad-hoc signed, not notarized. On another Mac, Gatekeeper will block the first launch:

1. Right-click **read.me**
2. Choose **Open**
3. Click **Open** again

After that, launch it from Applications or Spotlight.

### Use it

- **File → Open Folder…** (`⌘O`), or drop a folder on the Dock icon
- Terminal, after the `.pkg`: `read.me .`
- Terminal, if you only dragged the app: `/Applications/read.me.app/Contents/MacOS/read.me .`

A file path opens the parent folder and selects that file. `⌘0` toggles the sidebar. **View → Show Hidden** reveals dotfiles but never `.git` or `node_modules`.

Relative links in markdown stay in the app if the target is inside the open folder. `http`/`https` open in the browser.

---

## How to (developers)

Need **Xcode 16+** (Swift 6 / SwiftUI) on macOS 14+.

### Run tests

```bash
swift test
```

### Run the app from this repo

```bash
./scripts/bundle-app.sh
open dist/read.me.app
```

### Build the installers you can share

```bash
./scripts/package-installer.sh
```

Writes:

- `dist/read.me.app` — the app (universal `arm64` + `x86_64`)
- `dist/read.me-1.0.pkg` — installer + `read.me` CLI in `/usr/local/bin`
- `dist/read.me-1.0.dmg` — drag-to-Applications disk
- `dist/read.me-1.0.zip` — zipped app

### Daily loop

```bash
# open the current directory in the running app (or launch it)
dist/read.me.app/Contents/MacOS/read.me .

# after a pkg install, that is just:
read.me .
```

Rebuild the Dock icon from `Resources/AppIcon-1024.png` by running `bundle-app.sh` again (it writes `Resources/AppIcon.icns`).

### Layout

| Path | Role |
| --- | --- |
| `Sources/ReadMe/` | SwiftUI window, viewer, menus |
| `Sources/ReadMeCore/` | Session, tree, file loader, link routing |
| `Sources/ReadMeCLI/` | `read.me` command — finds `me.read.app` and opens a path |
| `Tests/ReadMeCoreTests/` | Swift Testing |
| `Fixtures/SampleProject/` | Fixture folder for tests |
| `Resources/` | App icon |
| `Info.plist` | Bundle metadata |
| `scripts/bundle-app.sh` | Release `.app`, icon, ad-hoc sign |
| `scripts/package-installer.sh` | `.pkg` + `.dmg` + `.zip` |

### What the code is allowed to do

- Read files under the open folder
- Hide junk directories at list time (not as a later filter)
- Refuse paths that escape the folder
- Skip files larger than 2 MB
- Follow system light/dark

It must not write the project, spawn a second window, or load a web view.

---

## License

Local developer utility. Display name **read.me**. Command **`read.me`**.
