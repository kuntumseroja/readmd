import SwiftUI

struct MarkdownDocumentView: View {
    let text: String
    let onLink: (String) -> Void

    var body: some View {
        ScrollView {
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
    }
}
