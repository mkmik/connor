import SwiftUI

struct FileNavigatorView: View {
    @EnvironmentObject var appState: AppState
    @State private var expandedFolders: Set<URL> = []
    @State private var files: [FileItem] = []
    @State private var isLoading = false

    var rootPath: URL? {
        appState.selectedWorkspace?.rootPath
    }

    var body: some View {
        Group {
            if rootPath != nil {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if files.isEmpty {
                    EmptyStateView(
                        icon: "folder",
                        title: "Empty Directory",
                        subtitle: "No files found"
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(files) { file in
                                FileRow(
                                    file: file,
                                    isExpanded: expandedFolders.contains(file.url),
                                    onToggleExpand: {
                                        toggleExpansion(file)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                EmptyStateView(
                    icon: "folder",
                    title: "No Workspace",
                    subtitle: "Select a workspace to browse files"
                )
            }
        }
        .onChange(of: rootPath) {
            if let path = rootPath {
                loadFiles(at: path)
            } else {
                files = []
            }
        }
        .onAppear {
            if let path = rootPath {
                loadFiles(at: path)
            }
        }
    }

    private func loadFiles(at url: URL) {
        isLoading = true
        expandedFolders = [url]

        Task {
            let items = await loadDirectory(url, depth: 0)
            await MainActor.run {
                files = items
                isLoading = false
            }
        }
    }

    private func toggleExpansion(_ file: FileItem) {
        guard file.isDirectory else { return }

        if expandedFolders.contains(file.url) {
            expandedFolders.remove(file.url)
            removeChildren(of: file)
        } else {
            expandedFolders.insert(file.url)
            insertChildren(of: file)
        }
    }

    private func loadDirectory(_ url: URL, depth: Int) async -> [FileItem] {
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: [.skipsHiddenFiles]
            )

            return contents
                .filter { !isHiddenOrIgnored($0) }
                .sorted { item1, item2 in
                    let isDir1 = (try? item1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    let isDir2 = (try? item2.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

                    if isDir1 != isDir2 {
                        return isDir1
                    }
                    return item1.lastPathComponent.localizedCaseInsensitiveCompare(item2.lastPathComponent) == .orderedAscending
                }
                .map { url in
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    return FileItem(url: url, isDirectory: isDir, depth: depth)
                }
        } catch {
            return []
        }
    }

    private func isHiddenOrIgnored(_ url: URL) -> Bool {
        let name = url.lastPathComponent

        // Skip common ignored patterns
        let ignoredPatterns = [".git", ".build", "node_modules", ".DS_Store", "__pycache__", ".swiftpm"]
        return ignoredPatterns.contains(name)
    }

    private func insertChildren(of file: FileItem) {
        guard let index = files.firstIndex(where: { $0.id == file.id }) else { return }

        Task {
            let children = await loadDirectory(file.url, depth: file.depth + 1)
            await MainActor.run {
                files.insert(contentsOf: children, at: index + 1)
            }
        }
    }

    private func removeChildren(of file: FileItem) {
        files.removeAll { item in
            item.depth > file.depth &&
            item.url.path.hasPrefix(file.url.path + "/")
        }
    }
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let isDirectory: Bool
    let depth: Int

    var name: String {
        url.lastPathComponent
    }

    var iconName: String {
        if isDirectory {
            return "folder.fill"
        }

        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "curlybraces"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml": return "doc.text"
        case "md", "txt": return "doc.plaintext"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        default: return "doc"
        }
    }

    var iconColor: Color {
        if isDirectory {
            return .blue
        }

        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "jsx": return .yellow
        case "ts", "tsx": return .blue
        case "py": return .green
        case "json": return .purple
        default: return .secondary
        }
    }
}

struct FileRow: View {
    @EnvironmentObject var appState: AppState
    let file: FileItem
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            // Indentation
            Color.clear
                .frame(width: CGFloat(file.depth) * 16)

            // Expand/collapse arrow for directories
            if file.isDirectory {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                    .onTapGesture(perform: onToggleExpand)
            } else {
                Color.clear.frame(width: 16)
            }

            // File icon
            Image(systemName: file.iconName)
                .font(.system(size: 12))
                .foregroundColor(file.iconColor)
                .frame(width: 16)

            // File name
            Text(file.name)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if file.isDirectory {
                onToggleExpand()
            } else {
                openFile(file.url)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func openFile(_ url: URL) {
        guard let workspaceId = appState.selectedWorkspaceId else { return }
        appState.sessionState(for: workspaceId).openFile(url)
    }
}

#Preview {
    FileNavigatorView()
        .environmentObject(AppState())
        .frame(width: 300, height: 400)
}
