import SwiftUI

struct PreferencesView: View {
    private enum Tab: String, CaseIterable {
        case general = "General"
        case themes = "Themes"
        case repositories = "Repositories"
        case hosting = "Git Hosting"
    }

    @State private var selectedTab: Tab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralPreferencesTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Tab.general)

            ThemePreferencesTab()
                .tabItem {
                    Label("Themes", systemImage: "paintpalette")
                }
                .tag(Tab.themes)

            RepositoriesPreferencesTab()
                .tabItem {
                    Label("Repositories", systemImage: "folder")
                }
                .tag(Tab.repositories)

            GitHostingPreferencesTab()
                .tabItem {
                    Label("Git Hosting", systemImage: "checkmark.circle")
                }
                .tag(Tab.hosting)
        }
        .frame(width: 600, height: 500)
    }
}

struct GeneralPreferencesTab: View {
    @EnvironmentObject var appState: AppState
    @State private var connorDirectory: String = ""
    @State private var selectedEditor: ExternalEditor = .cursor
    @State private var selectedTheme: AppTheme = .system
    @State private var branchPrefix: String = ""
    @State private var claudeBinaryName: String = "claude"
    @State private var fontSize: Double = 13
    @State private var selectedFontName: String = ""  // empty string means system monospace

    private var availableMonospaceFonts: [String] {
        let fontManager = NSFontManager.shared
        let monospaceFonts = fontManager.availableFontFamilies.filter { family in
            guard let font = NSFont(name: family, size: 12) else { return false }
            return font.isFixedPitch
        }
        return monospaceFonts.sorted()
    }

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
                TextField("Binary Name", text: $claudeBinaryName)
                    .textFieldStyle(.roundedBorder)

                Text("Name or path of the Claude CLI binary")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Claude CLI")
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

            Section {
                Picker("Font", selection: $selectedFontName) {
                    Text("System Monospace").tag("")
                    Divider()
                    ForEach(availableMonospaceFonts, id: \.self) { fontName in
                        Text(fontName)
                            .font(.custom(fontName, size: 13))
                            .tag(fontName)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Size")
                    Spacer()
                    Stepper(value: $fontSize, in: 9...24, step: 1) {
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                    }
                }

                Text("Affects terminals and file viewer")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Font")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            connorDirectory = appState.preferences.connorRootDirectory.path
            selectedEditor = appState.preferences.preferredEditor
            selectedTheme = appState.preferences.theme
            branchPrefix = appState.preferences.branchNamePrefix
            claudeBinaryName = appState.preferences.claudeBinaryName
            fontSize = Double(appState.preferences.monospaceFontSize)
            selectedFontName = appState.preferences.monospaceFontName ?? ""
        }
        .onChange(of: selectedEditor) {
            appState.preferences.preferredEditor = selectedEditor
            appState.savePreferences()
        }
        .onChange(of: selectedTheme) {
            appState.preferences.theme = selectedTheme
            appState.savePreferences()
        }
        .onChange(of: branchPrefix) {
            appState.preferences.branchNamePrefix = branchPrefix
            appState.savePreferences()
        }
        .onChange(of: claudeBinaryName) {
            appState.preferences.claudeBinaryName = claudeBinaryName
            appState.savePreferences()
        }
        .onChange(of: fontSize) {
            appState.preferences.monospaceFontSize = CGFloat(fontSize)
            appState.savePreferences()
            appState.notifyFontPreferencesChanged()
        }
        .onChange(of: selectedFontName) {
            appState.preferences.monospaceFontName = selectedFontName.isEmpty ? nil : selectedFontName
            appState.savePreferences()
            appState.notifyFontPreferencesChanged()
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

struct GitHostingPreferencesTab: View {
    @EnvironmentObject var appState: AppState
    @State private var providerType: GitHostingProviderType = .gitlab
    @State private var hostingURLString: String = ""
    @State private var hostingToken: String = ""
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus?

    enum ConnectionStatus {
        case success(String)
        case failure(String)
    }

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $providerType) {
                    ForEach(GitHostingProviderType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Provider")
            }

            Section {
                TextField("\(providerType.rawValue) URL", text: $hostingURLString, prompt: Text(providerType.urlPlaceholder))
                    .textFieldStyle(.roundedBorder)

                Text("Enter your \(providerType.rawValue) instance URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("\(providerType.rawValue) Instance")
            }

            Section {
                SecureField("Personal Access Token", text: $hostingToken)
                    .textFieldStyle(.roundedBorder)

                Text(providerType.tokenHelpText)
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
                    .disabled(hostingURLString.isEmpty || hostingToken.isEmpty || isTestingConnection)

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
                    saveHostingSettings()
                }
                .disabled(hostingURLString.isEmpty)
            } header: {
                Text("Connection")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            let config = appState.preferences.gitHostingConfig
            providerType = config.providerType
            hostingURLString = config.baseURL?.absoluteString ?? ""
            hostingToken = config.token ?? ""
        }
    }

    private func testConnection() {
        // TODO: Implement actual API connection test
        isTestingConnection = true
        connectionStatus = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isTestingConnection = false
            if URL(string: hostingURLString) != nil {
                connectionStatus = .success("URL is valid (API test not implemented)")
            } else {
                connectionStatus = .failure("Invalid URL format")
            }
        }
    }

    private func saveHostingSettings() {
        appState.preferences.gitHostingConfig = GitHostingConfig(
            providerType: providerType,
            baseURL: URL(string: hostingURLString),
            token: hostingToken.isEmpty ? nil : hostingToken
        )
        appState.savePreferences()
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager.shared)
}
