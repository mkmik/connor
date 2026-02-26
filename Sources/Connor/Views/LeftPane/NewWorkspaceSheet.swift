import SwiftUI

struct NewWorkspaceSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRepoURL: URL?
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showFilePicker = false

    private let workspaceManager = WorkspaceManager()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Workspace")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Recent repositories
                if !appState.preferences.recentRepositories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Repositories")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ForEach(appState.preferences.recentRepositories, id: \.self) { url in
                            RepoSelectionRow(
                                url: url,
                                isSelected: selectedRepoURL == url
                            ) {
                                selectedRepoURL = url
                            }
                        }
                    }
                }

                // Choose directory button
                VStack(alignment: .leading, spacing: 8) {
                    if !appState.preferences.recentRepositories.isEmpty {
                        Text("Or choose a repository")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        showFilePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text("Choose Repository...")
                        }
                    }
                    .fileImporter(
                        isPresented: $showFilePicker,
                        allowedContentTypes: [.folder],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                selectedRepoURL = url
                            }
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }

                // Selected repository display
                if let url = selectedRepoURL {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(url.lastPathComponent)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(url.deletingLastPathComponent().path)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }

                // Worktrunk toggle
                Toggle("Use Worktrunk", isOn: $appState.preferences.useWorktrunk)
                    .font(.system(size: 13))
                    .onChange(of: appState.preferences.useWorktrunk) {
                        appState.savePreferences()
                    }

                // Error message
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()

            Spacer()

            Divider()

            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Workspace") {
                    createWorkspace()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedRepoURL == nil || isCreating)
            }
            .padding()
        }
        .frame(width: 500, height: 450)
        .onAppear {
            if selectedRepoURL == nil, let firstRepo = appState.preferences.recentRepositories.first {
                selectedRepoURL = firstRepo
            }
        }
    }

    private func createWorkspace() {
        guard let repoURL = selectedRepoURL else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let workspace = try await workspaceManager.createWorkspace(
                    from: repoURL,
                    preferences: appState.preferences
                )

                await MainActor.run {
                    // Add to recent repositories
                    appState.preferences.addRecentRepository(repoURL)
                    appState.savePreferences()

                    // Add workspace
                    appState.addWorkspace(workspace)

                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

struct RepoSelectionRow: View {
    let url: URL
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    Text(url.deletingLastPathComponent().path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NewWorkspaceSheet()
        .environmentObject(AppState())
}
