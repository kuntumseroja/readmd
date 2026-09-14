public struct HideRules: Equatable, Sendable {
    public var showHidden: Bool

    public init(showHidden: Bool = false) {
        self.showHidden = showHidden
    }

    public static let alwaysHiddenDirectoryNames: Set<String> = [
        ".git", "node_modules", "dist", "build", ".next", "target",
        ".build", "DerivedData", ".venv", "venv", "__pycache__",
        ".turbo", ".cache", "coverage", "out",
    ]

    public func isListed(_ name: String, isDirectory: Bool) -> Bool {
        if isDirectory && Self.alwaysHiddenDirectoryNames.contains(name) {
            return false
        }
        if name.hasPrefix("."), !showHidden {
            return false
        }
        return true
    }
}
