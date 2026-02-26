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

    private var providerType: GitHostingProviderType {
        appState.preferences.gitHostingConfig.providerType
    }

    var hasHostingConfig: Bool {
        appState.preferences.gitHostingConfig.isConfigured
    }

    var body: some View {
        Group {
            if !hasHostingConfig {
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
        if state.isFetching && state.codeReview == nil {
            // Initial load - show spinner
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = state.errorMessage, state.codeReview == nil {
            // Error with no cached data
            errorView(error)
        } else if let review = state.codeReview {
            // Show code review (may be refreshing in background)
            codeReviewStatusView(review, isRefreshing: state.isFetching)
        } else {
            noCodeReviewView
        }
    }

    // MARK: - Code Review Status View

    private func codeReviewStatusView(_ review: CodeReview, isRefreshing: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CodeReviewHeaderCard(review: review, providerType: providerType)

                if let pipeline = review.pipeline {
                    PipelineStatusCard(pipeline: pipeline, providerType: providerType)
                } else {
                    NoPipelineCard()
                }

                // Actions
                HStack {
                    Button {
                        if let url = URL(string: review.webUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.square")
                            Text("Open in \(providerType.rawValue)")
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

    // MARK: - No Code Review View

    private var noCodeReviewView: some View {
        EmptyStateView(
            icon: "arrow.triangle.pull",
            title: "No \(providerType.codeReviewName)",
            subtitle: "Create a \(providerType.codeReviewAbbreviation) to see pipeline status"
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

    // MARK: - Not Configured

    private var placeholderWithoutConfig: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "gear.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))

            VStack(spacing: 4) {
                Text("Git Hosting Not Configured")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)

                Text("Configure your \(providerType.rawValue) instance in Preferences to see CI status")
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

// MARK: - Code Review Header Card

private struct CodeReviewHeaderCard: View {
    let review: CodeReview
    let providerType: GitHostingProviderType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.pull")
                    .foregroundColor(.secondary)

                Text("\(providerType.numberPrefix)\(review.number)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                CodeReviewStateBadge(state: review.state)
            }

            Text(review.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
    }
}

// MARK: - Code Review State Badge

private struct CodeReviewStateBadge: View {
    let state: CodeReviewState

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
        switch state {
        case .open: return "Open"
        case .merged: return "Merged"
        case .closed: return "Closed"
        }
    }

    private var badgeColor: Color {
        switch state {
        case .open: return .green
        case .merged: return Color(red: 137/255, green: 87/255, blue: 229/255) // purple
        case .closed: return .red
        }
    }
}

// MARK: - Pipeline Status Card

private struct PipelineStatusCard: View {
    let pipeline: CIPipeline
    let providerType: GitHostingProviderType

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
                    .help("Open pipeline in \(providerType.rawValue)")
                }
            }

            HStack(spacing: 8) {
                Image(systemName: pipeline.status.systemImageName)
                    .foregroundColor(pipeline.status.color)

                Text(pipeline.status.displayName)
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
