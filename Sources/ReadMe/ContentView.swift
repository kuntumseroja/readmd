import ReadMeCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var reader = ReaderController()
    @State private var isOpening = false

    var body: some View {
        NavigationSplitView {
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
                ViewerView(preview: reader.preview, onLink: { reader.handleLink($0) })
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
        .focusedSceneValue(\.reader, $reader)
        .focusedSceneValue(\.isOpening, $isOpening)
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
