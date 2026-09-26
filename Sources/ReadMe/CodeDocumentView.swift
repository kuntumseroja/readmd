import SwiftUI

struct CodeDocumentView: View {
    let text: String
    let language: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let highlighted = Highlighter.attributed(text, language: language, dark: colorScheme == .dark)
        ScrollView {
            HStack(alignment: .top, spacing: 12) {
                Text(lineNumbers(for: lines.count))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                Text(highlighted)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
    }

    private func lineNumbers(for count: Int) -> String {
        (1...max(count, 1)).map(String.init).joined(separator: "\n")
    }
}
