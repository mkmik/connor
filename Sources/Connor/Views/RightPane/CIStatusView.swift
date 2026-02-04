import SwiftUI

struct CIStatusView: View {
    @EnvironmentObject var appState: AppState

    var workspace: Workspace? {
        appState.selectedWorkspace
    }

    var sessionState: WorkspaceSessionState? {
        guard let id = appState.selectedWorkspaceId else { return nil }
        return appState.sessionState(for: id)
    }

    var checksState: ChecksState? {
        sessionState?.checksState
    }

    var hasGitLabConfig: Bool {
        guard appState.preferences.gitlabURL != nil,
              let token = appState.preferences.gitlabToken,
              !token.isEmpty else {
            return false
        }
        return true
    }

    var body: some View {
        Group {
            if !hasGitLabConfig {
                placeholderWithoutConfig
            } else if workspace == nil {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No Workspace",
                    subtitle: "Select a workspace to view CI status"
                )
            } else if let state = checksState {
                checksContent(state)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: workspace?.id) {
            loadIfNeeded()
        }
    }

    @ViewBuilder
    private func checksContent(_ state: ChecksState) -> some View {
        if state.isFetching && state.mergeRequest == nil {
            // Initial load - show spinner
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = state.errorMessage, state.mergeRequest == nil {
            // Error with no cached data
            errorView(error)
        } else if let mr = state.mergeRequest {
            // Show MR (may be refreshing in background)
            mrStatusView(mr, isRefreshing: state.isFetching)
        } else {
            noMRView
        }
    }

    // MARK: - MR Status View

    private func mrStatusView(_ mr: GitLabMergeRequest, isRefreshing: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MR Header
                MRHeaderCard(mr: mr)

                // Pipeline Status
                if let pipeline = mr.headPipeline {
                    PipelineStatusCard(pipeline: pipeline)
                } else {
                    NoPipelineCard()
                }

                // Actions
                HStack {
                    Button {
                        if let url = URL(string: mr.webUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.square")
                            Text("Open in GitLab")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button {
                        triggerRefresh()
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isRefreshing)
                    .help("Refresh CI status")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - No MR View

    private var noMRView: some View {
        EmptyStateView(
            icon: "arrow.triangle.pull",
            title: "No Merge Request",
            subtitle: "Create an MR to see pipeline status"
        )
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            Text(error)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                triggerRefresh()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - GitLab Not Configured

    private var placeholderWithoutConfig: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "gear.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))

            VStack(spacing: 4) {
                Text("GitLab Not Configured")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)

                Text("Configure your GitLab instance in Preferences to see CI status")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button("Open Preferences") {
                openPreferences()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    // MARK: - Data Loading

    private func loadIfNeeded() {
        guard let workspace = workspace,
              let sessionState = sessionState else { return }

        // Always fetch on workspace switch if data is stale
        if sessionState.checksState.isStale {
            appState.refreshChecks(for: workspace, sessionState: sessionState)
        }
    }

    private func triggerRefresh() {
        guard let workspace = workspace,
              let sessionState = sessionState else { return }
        appState.refreshChecks(for: workspace, sessionState: sessionState)
    }

    private func openPreferences() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

// MARK: - MR Header Card

private struct MRHeaderCard: View {
    let mr: GitLabMergeRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.pull")
                    .foregroundColor(.secondary)

                Text("!\(mr.iid)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                MRStateBadge(state: mr.state, isMerged: mr.isMerged)
            }

            Text(mr.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
    }
}

// MARK: - MR State Badge

private struct MRStateBadge: View {
    let state: String
    let isMerged: Bool

    var body: some View {
        Text(displayText)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .cornerRadius(4)
    }

    private var displayText: String {
        if isMerged {
            return "Merged"
        }
        return state.capitalized
    }

    private var badgeColor: Color {
        if isMerged {
            return Color(red: 137/255, green: 87/255, blue: 229/255) // purple
        }
        switch state {
        case "opened":
            return .green
        case "closed":
            return .red
        default:
            return .secondary
        }
    }
}

// MARK: - Pipeline Status Card

private struct PipelineStatusCard: View {
    let pipeline: GitLabPipeline

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pipeline")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if let url = pipeline.webUrl, let pipelineURL = URL(string: url) {
                    Button {
                        NSWorkspace.shared.open(pipelineURL)
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .help("Open pipeline in GitLab")
                }
            }

            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)

                Text(statusDisplayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Text("#\(pipeline.id)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }

    private var statusIcon: String {
        switch pipeline.status {
        case "success":
            return "checkmark.circle.fill"
        case "running":
            return "play.circle.fill"
        case "pending", "waiting_for_resource", "preparing":
            return "clock.fill"
        case "failed":
            return "xmark.circle.fill"
        case "canceled":
            return "stop.circle.fill"
        case "skipped":
            return "forward.circle.fill"
        case "manual":
            return "hand.raised.circle.fill"
        case "created":
            return "circle.dashed"
        default:
            return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch pipeline.status {
        case "success":
            return .green
        case "running":
            return .blue
        case "pending", "waiting_for_resource", "preparing", "manual":
            return .orange
        case "failed":
            return .red
        case "canceled", "skipped":
            return .secondary
        case "created":
            return .secondary
        default:
            return .secondary
        }
    }

    private var statusDisplayName: String {
        switch pipeline.status {
        case "success":
            return "Passed"
        case "running":
            return "Running"
        case "pending":
            return "Pending"
        case "failed":
            return "Failed"
        case "canceled":
            return "Canceled"
        case "skipped":
            return "Skipped"
        case "manual":
            return "Manual"
        case "created":
            return "Created"
        case "waiting_for_resource":
            return "Waiting"
        case "preparing":
            return "Preparing"
        default:
            return pipeline.status.capitalized
        }
    }
}

// MARK: - No Pipeline Card

private struct NoPipelineCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pipeline")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                Image(systemName: "minus.circle")
                    .foregroundColor(.secondary)

                Text("No Pipeline")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }
}

#Preview {
    CIStatusView()
        .environmentObject(AppState())
        .frame(width: 300, height: 400)
}
