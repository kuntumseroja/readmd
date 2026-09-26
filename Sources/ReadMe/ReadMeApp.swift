import AppKit
import ReadMeCore
import SwiftUI

private struct ReaderBindingKey: FocusedValueKey {
    typealias Value = Binding<ReaderController>
}

private struct OpeningBindingKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var reader: Binding<ReaderController>? {
        get { self[ReaderBindingKey.self] }
        set { self[ReaderBindingKey.self] = newValue }
    }

    var isOpening: Binding<Bool>? {
        get { self[OpeningBindingKey.self] }
        set { self[OpeningBindingKey.self] = newValue }
    }
}

@main
struct ReadMeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
    }
}

private struct OpenCloseFolderCommands: View {
    @FocusedBinding(\.reader) private var reader
    @FocusedBinding(\.isOpening) private var isOpening

    var body: some View {
        Button("Open Folder…") { isOpening = true }
            .keyboardShortcut("o", modifiers: .command)
        Button("Close Folder") {
            guard var reader else { return }
            reader.closeFolder()
            self.reader = reader
        }
    }
}

private struct ShowHiddenAndSidebarCommands: View {
    @FocusedBinding(\.reader) private var reader

    var body: some View {
        Toggle("Show Hidden", isOn: Binding(
            get: { reader?.session.showHidden ?? false },
            set: { show in
                guard var reader else { return }
                reader.setShowHidden(show)
                self.reader = reader
            }
        ))
        Button("Toggle Sidebar") {
            NSApp.keyWindow?.firstResponder?
                .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        }
        .keyboardShortcut("0", modifiers: .command)
    }
}
