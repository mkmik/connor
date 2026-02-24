import SwiftUI

struct FileViewerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let fileURL: URL
    @State private var content: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Could not load file",
                    subtitle: error
                )
            } else {
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical]) {
                        Text(content)
                            .font(monospaceFont)
                            .foregroundColor(Color(nsColor: ThemeManager.contrastingColor(for: themeManager.currentTheme.editorBackground.nsColor)))
                            .textSelection(.enabled)
                            .padding()
                            .frame(
                                minWidth: geometry.size.width,
                                minHeight: geometry.size.height,
                                alignment: .topLeading
                            )
                    }
                }
                .background(themeManager.currentTheme.editorBackground.color)
            }
        }
        .onAppear {
            loadFile()
        }
        .onChange(of: fileURL) {
            loadFile()
        }
    }

    private var monospaceFont: Font {
        let size = appState.preferences.monospaceFontSize
        if let fontName = appState.preferences.monospaceFontName {
            return .custom(fontName, size: size)
        }
        return .system(size: size, design: .monospaced)
    }

    private func loadFile() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let data = try Data(contentsOf: fileURL)
                let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .ascii)
                    ?? "[Binary file - cannot display]"

                await MainActor.run {
                    content = text
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    FileViewerView(fileURL: URL(fileURLWithPath: "/etc/hosts"))
        .environmentObject(AppState())
        .environmentObject(ThemeManager.shared)
        .frame(width: 600, height: 400)
}
