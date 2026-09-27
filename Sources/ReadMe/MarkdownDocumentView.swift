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
                .markdownInlineImageProvider(ProjectInlineImageProvider(
                    folderURL: folderURL,
                    currentFileURL: currentFileURL
                ))
                .environment(\.openURL, OpenURLAction { url in
                    onLink(url.absoluteString.hasPrefix("file:")
                           ? relativeHREF(from: url)
                           : (url.scheme == nil ? url.path : url.absoluteString))
                    return .handled
                })
                .frame(maxWidth: .infinity, alignment: .leading)
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
        ProjectImage(folderURL: folderURL, currentFileURL: currentFileURL, href: markdownImageHref(from: url))
    }
}

struct ProjectInlineImageProvider: InlineImageProvider {
    let folderURL: URL
    let currentFileURL: URL

    func image(with url: URL, label _: String) async throws -> Image {
        if let nsImage = projectNSImage(
            folderURL: folderURL,
            currentFileURL: currentFileURL,
            href: markdownImageHref(from: url)
        ) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "photo")
    }
}

private struct ProjectImage: View {
    let folderURL: URL
    let currentFileURL: URL
    let href: String

    var body: some View {
        if let image = projectNSImage(folderURL: folderURL, currentFileURL: currentFileURL, href: href) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "photo").foregroundStyle(.secondary)
        }
    }
}

private func markdownImageHref(from url: URL?) -> String {
    guard let url else { return "" }
    if url.scheme == nil { return url.relativeString }
    if url.isFileURL { return url.path }
    return url.absoluteString
}

private func projectNSImage(folderURL: URL, currentFileURL: URL, href: String) -> NSImage? {
    switch LinkRouter(folderURL: folderURL, currentFileURL: currentFileURL).decide(href: href) {
    case .select(let fileURL):
        return NSImage(contentsOf: fileURL)
    default:
        return nil
    }
}
