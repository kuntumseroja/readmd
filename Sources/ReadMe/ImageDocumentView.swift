import AppKit
import SwiftUI

struct ImageDocumentView: View {
    let url: URL

    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            UnavailableCard(
                name: url.lastPathComponent,
                size: (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0,
                type: url.pathExtension,
                reason: .unreadable
            )
        }
    }
}
