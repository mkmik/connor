import SwiftUI

struct CIStatusView: View {
    @EnvironmentObject var appState: AppState

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var mergeRequest: GitLabMergeRequest?
    @State private var refreshTask: Task<Void, Never>?

    var workspace: Workspace? {
        appState.selectedWorkspace
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
            } else if isLoading && mergeRequest == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                errorView(error)
            } else if let mr = mergeRequest {
                mrStatusView(mr)
            } else {
                noMRView
            }
        }
        .task(id: workspace?.id) {
            await loadMRStatus()
        }
        .onDisappear {
            cancelAutoRefresh()
        }
    }

    // MARK: - MR Status View

    private func mrStatusView(_ mr: GitLabMergeRequest) -> some View {
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
                        Task {
                            await loadMRStatus()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLoading)
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
                Task {
                    await loadMRStatus()
                }
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

    private func loadMRStatus() async {
        guard let workspace = workspace else { return }

        isLoading = true
        errorMessage = nil

        let service = GitLabService { appState.preferences }

        do {
            let mr = try await service.checkMRExists(for: workspace)
            await MainActor.run {
                self.mergeRequest = mr
                self.isLoading = false
                self.scheduleAutoRefresh(mr: mr)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func scheduleAutoRefresh(mr: GitLabMergeRequest?) {
        cancelAutoRefresh()

        // Only auto-refresh if pipeline is in progress
        guard let pipeline = mr?.headPipeline,
              pipeline.status == "running" || pipeline.status == "pending" else {
            return
        }

        refreshTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await loadMRStatus()
        }
    }

    private func cancelAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
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
