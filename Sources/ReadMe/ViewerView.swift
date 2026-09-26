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
