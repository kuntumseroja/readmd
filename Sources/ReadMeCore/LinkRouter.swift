import Foundation

public enum LinkDecision: Equatable, Sendable {
    case select(URL)
    case openExternal(URL)
    case ignore
}

public struct LinkRouter: Sendable {
    public var folderURL: URL
    public var currentFileURL: URL

    public init(folderURL: URL, currentFileURL: URL) {
        self.folderURL = folderURL.standardizedFileURL
        self.currentFileURL = currentFileURL.standardizedFileURL
    }

    public func decide(href: String) -> LinkDecision {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .ignore }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() {
            if scheme == "http" || scheme == "https" {
                return .openExternal(url)
            }
            if scheme != "file" {
                return .ignore
            }
        }

        let base = currentFileURL.deletingLastPathComponent()
        let target = URL(fileURLWithPath: trimmed, relativeTo: base).standardizedFileURL
        guard FileManager.default.fileExists(atPath: target.path) else { return .ignore }
        guard isInsideFolder(target) else { return .ignore }
        return .select(target)
    }

    private func isInsideFolder(_ url: URL) -> Bool {
        let folder = folderURL.path
        let path = url.path
        return path == folder || path.hasPrefix(folder.hasSuffix("/") ? folder : folder + "/")
    }
}
