import Foundation

public enum OpenFailure: Error, Equatable, Sendable {
    case missing
    case notFileOrDirectory
    case folderUnreadable
}

public struct OpenResult: Equatable, Sendable {
    public var folderURL: URL
    public var selectedURL: URL?
}

public struct AppSession: Equatable, Sendable {
    public var folderURL: URL?
    public var selectedURL: URL?
    public var showHidden: Bool

    public init(folderURL: URL? = nil, selectedURL: URL? = nil, showHidden: Bool = false) {
        self.folderURL = folderURL
        self.selectedURL = selectedURL
        self.showHidden = showHidden
    }

    public mutating func open(_ url: URL) -> Result<OpenResult, OpenFailure> {
        let url = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return .failure(.missing)
        }

        let folder: URL
        let selected: URL?
        if isDirectory.boolValue {
            folder = url
            selected = nil
        } else {
            folder = url.deletingLastPathComponent()
            selected = url
        }

        var reachable: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &reachable), reachable.boolValue else {
            return .failure(.notFileOrDirectory)
        }
        guard FileManager.default.isReadableFile(atPath: folder.path) else {
            return .failure(.folderUnreadable)
        }

        let opened = OpenResult(folderURL: folder, selectedURL: selected)
        folderURL = folder
        selectedURL = selected
        return .success(opened)
    }

    public mutating func closeFolder() {
        folderURL = nil
        selectedURL = nil
    }
}
