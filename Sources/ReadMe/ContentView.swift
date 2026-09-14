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
