import Foundation

public enum UnavailableReason: Equatable, Sendable {
    case binary
    case tooLarge
    case notText
    case permissionDenied
    case unreadable
}

public enum FilePreview: Equatable, Sendable {
    case markdown(String)
    case text(String, language: String?)
    case image(URL)
    case unavailable(name: String, size: Int64, type: String, reason: UnavailableReason)
}

public struct FileLoader: Equatable, Sendable {
    public static let maxByteCount = 2 * 1024 * 1024
    public var maxByteCount: Int

    public init(maxByteCount: Int = FileLoader.maxByteCount) {
        self.maxByteCount = maxByteCount
    }

    public func load(url: URL) -> FilePreview {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let type = ext.isEmpty ? "unknown" : ext

        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let size = Int64(values?.fileSize ?? 0)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .unavailable(name: name, size: 0, type: type, reason: .unreadable)
        }

        if size > Int64(maxByteCount) {
            return .unavailable(name: name, size: size, type: type, reason: .tooLarge)
        }

        if Self.imageExtensions.contains(ext) {
            return .image(url.standardizedFileURL)
        }

        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard let text = String(data: data, encoding: .utf8) else {
                return .unavailable(name: name, size: size, type: type, reason: .notText)
            }
            if Self.markdownExtensions.contains(ext) {
                return .markdown(text)
            }
            return .text(text, language: Self.language(for: ext))
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoPermissionError {
                return .unavailable(name: name, size: size, type: type, reason: .permissionDenied)
            }
            if error.domain == NSPOSIXErrorDomain && error.code == Int(EACCES) {
                return .unavailable(name: name, size: size, type: type, reason: .permissionDenied)
            }
            return .unavailable(name: name, size: size, type: type, reason: .unreadable)
        }
    }

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown"]
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "svg"]

    private static func language(for ext: String) -> String? {
        switch ext {
        case "js", "mjs", "cjs", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "go": return "go"
        case "rs": return "rust"
        case "swift": return "swift"
        case "json": return "json"
        case "yml", "yaml": return "yaml"
        case "toml": return "toml"
        case "css": return "css"
        case "html", "htm": return "html"
        case "sh", "bash", "zsh": return "shell"
        default: return nil
        }
    }
}
