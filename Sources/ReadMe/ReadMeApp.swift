import AppKit
import SwiftUI

private struct OpeningBindingKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var isOpening: Binding<Bool>? {
        get { self[OpeningBindingKey.self] }
        set { self[OpeningBindingKey.self] = newValue }
    }
}

@main
struct ReadMeApp: App {
    @StateObject private var store = ReaderStore.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("read.me", id: "main") {
            ContentView()
                .environmentObject(store)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                OpenCloseFolderCommands()
            }
            CommandMenu("View") {
                ShowHiddenAndSidebarCommands()
            }
        }
        .defaultSize(width: 960, height: 640)
        .handlesExternalEvents(matching: Set(["*"]))
    }
}

private struct OpenCloseFolderCommands: View {
    @ObservedObject private var store = ReaderStore.shared
    @FocusedBinding(\.isOpening) private var isOpening

    var body: some View {
        Button("Open Folder…") { isOpening = true }
            .keyboardShortcut("o", modifiers: .command)
        Button("Close Folder") {
            store.update { controller in
                controller.closeFolder()
            }
        }
    }
}

private struct ShowHiddenAndSidebarCommands: View {
    @ObservedObject private var store = ReaderStore.shared

    var body: some View {
        Toggle("Show Hidden", isOn: Binding(
            get: { store.reader.session.showHidden },
            set: { show in
                store.update { controller in
                    controller.setShowHidden(show)
                }
            }
        ))
        Button("Toggle Sidebar") {
            NSApp.keyWindow?.firstResponder?
                .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        }
        .keyboardShortcut("0", modifiers: .command)
    }
}
