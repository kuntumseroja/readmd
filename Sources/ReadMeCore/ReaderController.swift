import Foundation

public struct ReaderController: Equatable {
    public var session: AppSession
    public var preview: FilePreview?
    public var openError: OpenFailure?
    private var loader: FileLoader

    public init(session: AppSession = AppSession(), loader: FileLoader = FileLoader()) {
        self.session = session
        self.loader = loader
    }

    public mutating func open(_ url: URL) {
        switch session.open(url) {
        case .success:
            openError = nil
            reloadPreview()
        case .failure(let error):
            openError = error
        }
    }

    public mutating func closeFolder() {
        session.closeFolder()
        preview = nil
        openError = nil
    }

    public mutating func select(_ url: URL?) {
        session.selectedURL = url
        reloadPreview()
    }

    public mutating func setShowHidden(_ show: Bool) {
        session.showHidden = show
    }

    public mutating func handleLink(_ href: String) {
        if case .select(let url) = linkDecision(for: href) {
            select(url)
        }
    }

    public func linkDecision(for href: String) -> LinkDecision {
        guard let folder = session.folderURL, let current = session.selectedURL else {
            return .ignore
        }
        return LinkRouter(folderURL: folder, currentFileURL: current).decide(href: href)
    }

    private mutating func reloadPreview() {
        guard let selected = session.selectedURL else {
            preview = nil
            return
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: selected.path, isDirectory: &isDirectory), isDirectory.boolValue {
            preview = nil
            return
        }
        preview = loader.load(url: selected)
    }
}
