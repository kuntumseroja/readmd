import ReadMeCore
import SwiftUI

@MainActor
final class ReaderStore: ObservableObject {
    static let shared = ReaderStore()

    @Published var reader = ReaderController()
    @Published var showSidebar = true

    private init() {}

    func open(_ url: URL) {
        update { controller in
            controller.open(url)
        }
    }

    func update(_ body: (inout ReaderController) -> Void) {
        body(&reader)
    }
}
