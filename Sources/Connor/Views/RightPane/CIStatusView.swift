import SwiftUI

struct CIStatusView: View {
    @EnvironmentObject var appState: AppState

    var hasGitLabConfig: Bool {
        appState.preferences.gitlabURL != nil
    }

    var body: some View {
        if hasGitLabConfig {
            // TODO: Implement GitLab CI integration
            placeholderWithConfig
        } else {
            placeholderWithoutConfig
        }
    }

    private var placeholderWithConfig: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))

            VStack(spacing: 4) {
                Text("GitLab CI")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)

                Text("CI status will appear here when a merge request is created")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            // Placeholder for future implementation
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                    Text("Pipeline Status")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("—")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                    Text("Build")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("—")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                    Text("Test")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

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

    private func openPreferences() {
        // Open the Settings window
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

#Preview {
    CIStatusView()
        .environmentObject(AppState())
        .frame(width: 300, height: 400)
}
