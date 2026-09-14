import Foundation

public struct FileNode: Identifiable, Equatable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let isDirectory: Bool
}

public struct FileTree: Equatable, Sendable {
    public var root: URL
    public var rules: HideRules

    public init(root: URL, rules: HideRules = HideRules()) {
        self.root = root.standardizedFileURL
        self.rules = rules
    }

    public func children(of url: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }

        var nodes: [FileNode] = []
        for child in urls {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values?.isDirectory == true
            let name = child.lastPathComponent
            guard rules.isListed(name, isDirectory: isDirectory) else { continue }
            nodes.append(FileNode(url: child.standardizedFileURL, name: name, isDirectory: isDirectory))
        }

        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    public func expandingAncestors(to url: URL) -> [URL] {
        let rootPath = root.standardizedFileURL.path
        var current = url.standardizedFileURL.deletingLastPathComponent()
        var result: [URL] = []
        while current.path.hasPrefix(rootPath) {
            result.append(current)
            if current.path == rootPath { break }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        return result
    }
}
