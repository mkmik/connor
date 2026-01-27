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
            case .hasMR:
                // Don't show anything if MR already exists
                EmptyView()
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
        print("TODO")
    }
}

#Preview {
    CreateMRButton()
        .environmentObject(AppState())
        .padding()
}
