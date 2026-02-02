import SwiftUI

/// Button to create a GitLab Merge Request
struct CreateMRButton: View {
    @EnvironmentObject var appState: AppState

    @State private var mrStatus: MRStatus = .loading
    @State private var existingMR: GitLabMergeRequest?

    private let gitLabService: GitLabService

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

    init() {
        // Capture preferences access in a way that works with the service
        self.gitLabService = GitLabService { Preferences.default }
    }

    var body: some View {
        Group {
            let _ = print("[CreateMRButton] Rendering body, status: \(mrStatus), workspace: \(appState.selectedWorkspace?.id.uuidString ?? "nil")")
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
        .task(id: appState.selectedWorkspace?.id) {
            print("[CreateMRButton] Task triggered for workspace: \(appState.selectedWorkspace?.id.uuidString ?? "nil")")
            await checkMRStatus()
        }
        .onChange(of: appState.selectedWorkspace?.currentBranch) { _, _ in
            Task {
                await checkMRStatus()
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

    private func checkMRStatus() async {
        // Reset to loading state
        mrStatus = .loading

        // Check if GitLab is configured
        guard let gitlabURL = appState.preferences.gitlabURL else {
            print("[CreateMRButton] GitLab URL not configured")
            mrStatus = .notConfigured
            return
        }

        guard let token = appState.preferences.gitlabToken, !token.isEmpty else {
            print("[CreateMRButton] GitLab token not configured")
            mrStatus = .notConfigured
            return
        }

        guard let workspace = appState.selectedWorkspace else {
            print("[CreateMRButton] No workspace selected")
            mrStatus = .notConfigured
            return
        }

        print("[CreateMRButton] Checking MR for branch '\(workspace.currentBranch ?? "unknown")' at \(gitlabURL)")

        // Create a service with current preferences
        let service = GitLabService { [appState] in
            appState.preferences
        }

        do {
            if let mr = try await service.checkMRExists(for: workspace) {
                print("[CreateMRButton] Found existing MR: \(mr.webUrl)")
                mrStatus = .hasMR(mr)
                existingMR = mr
            } else {
                print("[CreateMRButton] No MR found, showing button")
                mrStatus = .noMR
                existingMR = nil
            }
        } catch {
            print("[CreateMRButton] Error checking MR: \(error.localizedDescription)")
            mrStatus = .error(error.localizedDescription)
            existingMR = nil
        }
    }

    private func createMR() {
        guard let gitlabURL = appState.preferences.gitlabURL,
              let workspace = appState.selectedWorkspace,
              let rootPath = workspace.rootPath,
              let branch = workspace.currentBranch else {
            return
        }

        Task {
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
