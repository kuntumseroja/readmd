import ReadMeCore
import SwiftUI

struct FileTreeView: View {
    let root: URL
    let showHidden: Bool
    @Binding var selectedURL: URL?
    @State private var expanded: Set<URL> = []

    var body: some View {
        let tree = FileTree(root: root, rules: HideRules(showHidden: showHidden))
        List {
            ForEach(tree.children(of: root)) { node in
                FileOutline(node: node, tree: tree, expanded: $expanded, selectedURL: $selectedURL)
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            expanded.insert(root)
            if let selectedURL {
                for url in tree.expandingAncestors(to: selectedURL) {
                    expanded.insert(url)
                }
            }
        }
        .onChange(of: selectedURL) { _, newValue in
            guard let newValue else { return }
            for url in tree.expandingAncestors(to: newValue) {
                expanded.insert(url)
            }
        }
    }
}

struct FileOutline: View {
    let node: FileNode
    let tree: FileTree
    @Binding var expanded: Set<URL>
    @Binding var selectedURL: URL?

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: Binding(
                get: { expanded.contains(node.url) },
                set: { isOn in
                    if isOn { expanded.insert(node.url) } else { expanded.remove(node.url) }
                }
            )) {
                ForEach(tree.children(of: node.url)) { child in
                    FileOutline(node: child, tree: tree, expanded: $expanded, selectedURL: $selectedURL)
                }
            } label: {
                Label(node.name, systemImage: FileIcon.systemName(for: node))
            }
        } else {
            Label(node.name, systemImage: FileIcon.systemName(for: node))
                .lineLimit(1)
                .foregroundStyle(selectedURL == node.url ? Color.accentColor : Color.primary)
                .onTapGesture { selectedURL = node.url }
        }
    }
}
