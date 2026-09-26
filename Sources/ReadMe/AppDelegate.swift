import AppKit

@MainActor
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
