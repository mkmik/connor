import SwiftUI

/// Button to create a code review (MR on GitLab, PR on GitHub)
struct CreateCodeReviewButton: View {
    @EnvironmentObject var appState: AppState

    // MARK: - Computed Properties (derived from checksState)

    private var sessionState: WorkspaceSessionState? {
        guard let id = appState.selectedWorkspaceId else { return nil }
        return appState.sessionState(for: id)
    }

    private var checksState: ChecksState? {
        sessionState?.checksState
    }

    private var providerType: GitHostingProviderType {
        appState.preferences.gitHostingConfig.providerType
    }

    private var hasHostingConfig: Bool {
        appState.preferences.gitHostingConfig.isConfigured
    }

    /// Derives status from checksState
    private var status: Status {
        guard hasHostingConfig else {
            return .notConfigured
        }

        guard appState.selectedWorkspace != nil else {
            return .notConfigured
        }

        guard let state = checksState else {
            return .loading
        }

        // Currently fetching with no cached data
        if state.isFetching && state.codeReview == nil && state.errorMessage == nil {
            return .loading
        }

        // Has a code review
        if let review = state.codeReview {
            return .hasCodeReview(review)
        }

        // Error state (only if we don't have cached data)
        if let error = state.errorMessage {
            return .error(error)
        }

        // No code review exists
        return .none
    }

    private enum Status {
        case loading
        case none
        case hasCodeReview(CodeReview)
        case error(String)
        case notConfigured
    }

    var body: some View {
        Group {
            switch status {
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 22)
            case .none:
                createButton
            case .hasCodeReview(let review):
                viewButton(review: review)
            case .error, .notConfigured:
                EmptyView()
            }
        }
    }

    private func viewButton(review: CodeReview) -> some View {
        Button {
            if let url = URL(string: review.webUrl) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.pull")
                Text("\(providerType.codeReviewAbbreviation) \(providerType.numberPrefix)\(review.number) \u{2197}")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(buttonColor(for: review))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help("Open \(providerType.codeReviewName) in browser")
    }

    private func buttonColor(for review: CodeReview) -> Color {
        if review.state == .merged {
            return Color(red: 137/255, green: 87/255, blue: 229/255)  // #8957e5
        } else if review.pipeline?.status == .failed {
            return Color(red: 207/255, green: 34/255, blue: 46/255)  // #cf222e
        } else if review.pipeline?.status == .success {
            return Color.green
        } else if review.pipeline?.status.isRunning == true {
            return Color.orange
        } else {
            return Color.accentColor
        }
    }

    private var createButton: some View {
        Menu {
            Button("Create \(providerType.codeReviewName)...") {
                createCodeReview()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.pull")
                Text("Create \(providerType.codeReviewAbbreviation)")
            }
        } primaryAction: {
            createCodeReview()
        }
        .menuIndicator(.visible)
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .help("Create a \(providerType.codeReviewName) for this branch")
    }

    private func createCodeReview() {
        let config = appState.preferences.gitHostingConfig
        guard let baseURL = config.baseURL,
              let workspace = appState.selectedWorkspace,
              let rootPath = workspace.rootPath,
              let branch = workspace.currentBranch else {
            return
        }

        Task {
            let provider = GitHostingProviderFactory.makeProvider { appState.preferences.gitHostingConfig }

            guard let remoteURL = try? await provider.getRemoteURL(at: rootPath),
                  let projectPath = provider.extractProjectPath(from: remoteURL) else {
                return
            }

            // Push the branch to remote before opening the code review page
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
                print("[CreateCodeReviewButton] Failed to push branch: \(error)")
            }

            if let url = provider.newCodeReviewURL(baseURL: baseURL, projectPath: projectPath, branch: branch) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

#Preview {
    CreateCodeReviewButton()
        .environmentObject(AppState())
        .padding()
}
