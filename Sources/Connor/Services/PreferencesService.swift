import Foundation

/// Service for persisting preferences to UserDefaults
final class PreferencesService {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let preferences = "com.connor.preferences"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Preferences {
        guard let data = defaults.data(forKey: Keys.preferences),
              let preferences = try? decoder.decode(Preferences.self, from: data) else {
            return .default
        }
        return preferences
    }

    func save(_ preferences: Preferences) {
        if let data = try? encoder.encode(preferences) {
            defaults.set(data, forKey: Keys.preferences)
        }
    }
}

/// Service for persisting workspace list to JSON file
final class WorkspaceStorageService {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default

    private func workspacesFilePath(rootDirectory: URL) -> URL {
        rootDirectory.appendingPathComponent("workspaces.json")
    }

    func load(rootDirectory: URL) -> [Workspace] {
        let filePath = workspacesFilePath(rootDirectory: rootDirectory)

        guard fileManager.fileExists(atPath: filePath.path),
              let data = try? Data(contentsOf: filePath),
              let workspaces = try? decoder.decode([Workspace].self, from: data) else {
            return []
        }

        return workspaces
    }

    func save(_ workspaces: [Workspace], rootDirectory: URL) {
        // Ensure root directory exists
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let filePath = workspacesFilePath(rootDirectory: rootDirectory)

        if let data = try? encoder.encode(workspaces) {
            try? data.write(to: filePath)
        }
    }
}
