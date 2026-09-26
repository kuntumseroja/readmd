import ReadMeCore
import SwiftUI

struct ViewerView: View {
    let preview: FilePreview?
    let folderURL: URL?
    let currentFileURL: URL?
    let onLink: (String) -> Void

    var body: some View {
        switch preview {
        case .markdown(let text):
            if let folderURL, let currentFileURL {
                MarkdownDocumentView(
                    text: text,
                    folderURL: folderURL,
                    currentFileURL: currentFileURL,
                    onLink: onLink
                )
            } else {
                Text("Select a file")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
