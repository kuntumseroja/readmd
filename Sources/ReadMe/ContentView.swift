import AppKit
import ReadMeCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: ReaderStore
    @State private var isOpening = false

    var body: some View {
        NavigationSplitView {
            if let folder = store.reader.session.folderURL {
                FileTreeView(
                    root: folder,
                    showHidden: store.reader.session.showHidden,
                    selectedURL: Binding(
                        get: { store.reader.session.selectedURL },
                        set: { url in
                            store.update { controller in
                                controller.select(url)
                            }
                        }
                    )
                )
            } else {
                EmptyView()
            }
        } detail: {
            if store.reader.session.folderURL == nil {
                VStack(spacing: 8) {
                    Text("Open a folder")
                        .font(.title2)
                    Text("⌘O or read.me .")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ViewerView(
                    preview: store.reader.preview,
                    folderURL: store.reader.session.folderURL,
                    currentFileURL: store.reader.session.selectedURL,
                    onLink: { href in
                        let decision = store.reader.linkDecision(for: href)
                        if case .openExternal(let url) = decision {
                            NSWorkspace.shared.open(url)
                        } else {
                            store.update { controller in
                                controller.handleLink(href)
                            }
                        }
                    }
                )
            }
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 220, max: 320)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text(store.reader.session.folderURL?.lastPathComponent ?? "read.me")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Open Folder…") { isOpening = true }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
        .fileImporter(isPresented: $isOpening, allowedContentTypes: [.folder], onCompletion: handleOpenResult)
        .alert("Can’t open", isPresented: Binding(
            get: { store.reader.openError != nil },
            set: { if !$0 { store.update { $0.openError = nil } } }
        )) {
            Button("OK", role: .cancel) {
                store.update { $0.openError = nil }
            }
        } message: {
            Text(openErrorMessage)
        }
        .onOpenURL { url in
            store.update { controller in
                controller.open(url)
            }
        }
        .focusedSceneValue(\.isOpening, $isOpening)
    }

    private var openErrorMessage: String {
        switch store.reader.openError {
        case .missing: return "That path does not exist."
        case .notFileOrDirectory: return "That path is not a file or folder."
        case .folderUnreadable: return "That folder is not readable."
        case nil: return ""
        }
    }

    private func handleOpenResult(_ result: Result<URL, Error>) {
        if case .success(let url) = result {
            store.update { controller in
                controller.open(url)
            }
        }
    }
}
