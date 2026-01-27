import SwiftUI

struct PreferencesView: View {
    private enum Tab: String, CaseIterable {
        case general = "General"
        case repositories = "Repositories"
        case gitlab = "GitLab"
    }

    @State private var selectedTab: Tab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralPreferencesTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Tab.general)

            RepositoriesPreferencesTab()
                .tabItem {
                    Label("Repositories", systemImage: "folder")
                }
                .tag(Tab.repositories)

            GitLabPreferencesTab()
                .tabItem {
                    Label("GitLab", systemImage: "checkmark.circle")
                }
                .tag(Tab.gitlab)
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralPreferencesTab: View {
    @EnvironmentObject var appState: AppState
    @State private var connorDirectory: String = ""
    @State private var selectedEditor: ExternalEditor = .cursor
    @State private var selectedTheme: AppTheme = .system
    @State private var branchPrefix: String = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Workspace Directory", text: $connorDirectory)
                        .textFieldStyle(.roundedBorder)

                    Button("Choose...") {
                        chooseDirectory()
                    }
                }

                Text("New workspaces will be created in this directory")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Storage")
            }

            Section {
                TextField("Branch Prefix", text: $branchPrefix)
                    .textFieldStyle(.roundedBorder)

                Text("Git branches will be named <prefix>/<workspace-name>")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Git")
            }

            Section {
                Picker("Default Editor", selection: $selectedEditor) {
                    ForEach(ExternalEditor.allCases) { editor in
                        Text(editor.rawValue).tag(editor)
                    }
                }
                .pickerStyle(.menu)

                Text("Used when opening workspaces in external applications")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Editor")
            }

            Section {
                Picker("Appearance", selection: $selectedTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Theme")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            connorDirectory = appState.preferences.connorRootDirectory.path
            selectedEditor = appState.preferences.preferredEditor
            selectedTheme = appState.preferences.theme
            branchPrefix = appState.preferences.branchNamePrefix
        }
        .onChange(of: selectedEditor) { newValue in
            appState.preferences.preferredEditor = newValue
            appState.savePreferences()
        }
        .onChange(of: selectedTheme) { newValue in
            appState.preferences.theme = newValue
            appState.savePreferences()
        }
        .onChange(of: branchPrefix) { newValue in
            appState.preferences.branchNamePrefix = newValue
            appState.savePreferences()
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select the directory where Connor will store workspaces"

        if panel.runModal() == .OK, let url = panel.url {
            connorDirectory = url.path
            appState.preferences.connorRootDirectory = url
            appState.savePreferences()
        }
    }
}

struct RepositoriesPreferencesTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Repositories")
                .font(.headline)

            if appState.preferences.recentRepositories.isEmpty {
                Text("No recent repositories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                List {
                    ForEach(appState.preferences.recentRepositories, id: \.self) { url in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent)
                                    .font(.system(size: 13, weight: .medium))

                                Text(url.deletingLastPathComponent().path)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }

                            Spacer()

                            Button {
                                removeRepository(url)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.bordered)
            }

            HStack {
                Button("Clear All") {
                    clearAllRepositories()
                }
                .disabled(appState.preferences.recentRepositories.isEmpty)

                Spacer()
            }
        }
        .padding()
    }

    private func removeRepository(_ url: URL) {
        appState.preferences.recentRepositories.removeAll { $0 == url }
        appState.savePreferences()
    }

    private func clearAllRepositories() {
        appState.preferences.recentRepositories.removeAll()
        appState.savePreferences()
    }
}

struct GitLabPreferencesTab: View {
    @EnvironmentObject var appState: AppState
    @State private var gitlabURLString: String = ""
    @State private var gitlabToken: String = ""
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus?

    enum ConnectionStatus {
        case success(String)
        case failure(String)
    }

    var body: some View {
        Form {
            Section {
                TextField("GitLab URL", text: $gitlabURLString, prompt: Text("https://gitlab.example.com"))
                    .textFieldStyle(.roundedBorder)

                Text("Enter your self-hosted GitLab instance URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("GitLab Instance")
            }

            Section {
                SecureField("Personal Access Token", text: $gitlabToken)
                    .textFieldStyle(.roundedBorder)

                Text("Create a token with api scope in GitLab > Settings > Access Tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Authentication")
            }

            Section {
                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(gitlabURLString.isEmpty || gitlabToken.isEmpty || isTestingConnection)

                    if isTestingConnection {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()

                    if let status = connectionStatus {
                        switch status {
                        case .success(let message):
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(message)
                                    .foregroundColor(.green)
                            }
                            .font(.caption)

                        case .failure(let message):
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(message)
                                    .foregroundColor(.red)
                            }
                            .font(.caption)
                        }
                    }
                }

                Button("Save") {
                    saveGitLabSettings()
                }
                .disabled(gitlabURLString.isEmpty)
            } header: {
                Text("Connection")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            gitlabURLString = appState.preferences.gitlabURL?.absoluteString ?? ""
            gitlabToken = appState.preferences.gitlabToken ?? ""
        }
    }

    private func testConnection() {
        // TODO: Implement actual GitLab API connection test
        isTestingConnection = true
        connectionStatus = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isTestingConnection = false
            // For now, just validate the URL format
            if URL(string: gitlabURLString) != nil {
                connectionStatus = .success("URL is valid (API test not implemented)")
            } else {
                connectionStatus = .failure("Invalid URL format")
            }
        }
    }

    private func saveGitLabSettings() {
        appState.preferences.gitlabURL = URL(string: gitlabURLString)
        appState.preferences.gitlabToken = gitlabToken.isEmpty ? nil : gitlabToken
        appState.savePreferences()
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AppState())
}
