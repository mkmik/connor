import SwiftUI

/// Button to create a GitLab Merge Request
struct CreateMRButton: View {
    @EnvironmentObject var appState: AppState

    // MARK: - Computed Properties (derived from checksState)

    private var sessionState: WorkspaceSessionState? {
        guard let id = appState.selectedWorkspaceId else { return nil }
        return appState.sessionState(for: id)
    }

    private var checksState: ChecksState? {
        sessionState?.checksState
    }

    private var hasGitLabConfig: Bool {
        guard appState.preferences.gitlabURL != nil,
              let token = appState.preferences.gitlabToken,
              !token.isEmpty else {
            return false
        }
        return true
    }

    /// Derives MRStatus from checksState
    private var mrStatus: MRStatus {
        guard hasGitLabConfig else {
            return .notConfigured
        }

        guard appState.selectedWorkspace != nil else {
            return .notConfigured
        }

        guard let state = checksState else {
            return .loading
        }

        // Currently fetching with no cached data
        if state.isFetching && state.mergeRequest == nil && state.errorMessage == nil {
            return .loading
        }

        // Has an MR
        if let mr = state.mergeRequest {
            return .hasMR(mr)
        }

        // Error state (only if we don't have cached MR data)
        if let error = state.errorMessage {
            return .error(error)
        }

        // No MR exists
        return .noMR
    }

    enum MRStatus: CustomStringConvertible {
        case loading
        case noMR
        case hasMR(GitLabMergeRequest)
        case error(String)
        case notConfigured

        var description: String {
            switch self {
            case .loading: return "loading"
            case .noMR: return "noMR"
            case .hasMR: return "hasMR"
            case .error(let msg): return "error(\(msg))"
            case .notConfigured: return "notConfigured"
            }
        }
    }

    var body: some View {
        Group {
            switch mrStatus {
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 22)
            case .noMR:
                createMRButton
            case .hasMR(let mr):
                viewMRButton(mr: mr)
            case .error, .notConfigured:
                // Don't show if there's an error or not configured
                EmptyView()
            }
        }
    }

    private func viewMRButton(mr: GitLabMergeRequest) -> some View {
        Button {
            if let url = URL(string: mr.webUrl) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.pull")
                Text("View MR")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(buttonColor(for: mr))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help("Open Merge Request in browser")
    }

    private func buttonColor(for mr: GitLabMergeRequest) -> Color {
        if mr.isMerged {
            // GitHub "merged" purple palette
            return Color(red: 137/255, green: 87/255, blue: 229/255)  // #8957e5
        } else if mr.hasPipelineSuccess {
            // Green for successful pipeline
            return Color.green
        } else if mr.hasPipelineRunning {
            // Orange for pipeline in progress
            return Color.orange
        } else {
            // Default accent color for open MRs
            return Color.accentColor
        }
    }

    private var createMRButton: some View {
        Menu {
            Button("Create Merge Request...") {
                createMR()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.pull")
                Text("Create MR")
            }
        } primaryAction: {
            createMR()
        }
        .menuIndicator(.visible)
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .help("Create a GitLab Merge Request for this branch")
    }

    private func createMR() {
        guard let gitlabURL = appState.preferences.gitlabURL,
              let workspace = appState.selectedWorkspace,
              let rootPath = workspace.rootPath,
              let branch = workspace.currentBranch else {
            return
        }

        Task {
            let gitLabService = GitLabService { [appState] in
                appState.preferences
            }

            guard let remoteURL = try? await gitLabService.getRemoteURL(at: rootPath),
                  let projectPath = gitLabService.extractProjectPath(from: remoteURL) else {
                return
            }

            // Push the branch to remote before opening the MR page
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["push", "--force-with-lease", "-u", "origin", branch]
            process.currentDirectoryURL = rootPath
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("[CreateMRButton] Failed to push branch: \(error)")
            }

            // GitLab new MR URL format: {baseURL}/{project}/-/merge_requests/new?merge_request[source_branch]={branch}
            let urlString = "\(gitlabURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/\(projectPath)/-/merge_requests/new?merge_request[source_branch]=\(branch)"

            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

#Preview {
    CreateMRButton()
        .environmentObject(AppState())
        .padding()
}
