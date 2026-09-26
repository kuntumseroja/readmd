import AppKit
import MarkdownUI
import ReadMeCore
import SwiftUI

struct MarkdownDocumentView: View {
    let text: String
    let folderURL: URL
    let currentFileURL: URL
    let onLink: (String) -> Void

    var body: some View {
        ScrollView {
            Markdown(text)
                .markdownTheme(.basic)
                .textSelection(.enabled)
                .markdownImageProvider(ProjectImageProvider(
                    folderURL: folderURL,
                    currentFileURL: currentFileURL
                ))
                .environment(\.openURL, OpenURLAction { url in
                    onLink(url.absoluteString.hasPrefix("file:")
                           ? relativeHREF(from: url)
                           : (url.scheme == nil ? url.path : url.absoluteString))
                    return .handled
                })
                .frame(maxWidth: 800, alignment: .leading)
                .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func relativeHREF(from url: URL) -> String {
        let path = url.path
        let folder = folderURL.standardizedFileURL.path
        if path == folder || path.hasPrefix(folder.hasSuffix("/") ? folder : folder + "/") {
            return path
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL.path
        if path == cwd { return "" }
        let prefix = cwd.hasSuffix("/") ? cwd : cwd + "/"
        if path.hasPrefix(prefix) {
            return String(path.dropFirst(prefix.count))
        }
        return path
    }
}

struct ProjectImageProvider: ImageProvider {
    let folderURL: URL
    let currentFileURL: URL

    @ViewBuilder
    func makeImage(url: URL?) -> some View {
        ProjectImage(folderURL: folderURL, currentFileURL: currentFileURL, href: href(from: url))
    }

    private func href(from url: URL?) -> String {
        guard let url else { return "" }
        if url.scheme == nil { return url.relativeString }
        if url.isFileURL { return url.path }
        return url.absoluteString
    }
}

private struct ProjectImage: View {
    let folderURL: URL
    let currentFileURL: URL
    let href: String

    var body: some View {
        switch LinkRouter(folderURL: folderURL, currentFileURL: currentFileURL).decide(href: href) {
        case .select(let fileURL):
            if let image = NSImage(contentsOf: fileURL) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        default:
            Image(systemName: "photo").foregroundStyle(.secondary)
        }
    }
}
