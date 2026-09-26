import ReadMeCore
import SwiftUI

struct UnavailableCard: View {
    let name: String
    let size: Int64
    let type: String
    let reason: UnavailableReason

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.title2)
            Text(byteCount).foregroundStyle(.secondary)
            Text(type).foregroundStyle(.secondary)
            Text(UnavailableCopy.message(for: reason))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var byteCount: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
