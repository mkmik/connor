import SwiftUI

struct NewThemeSheet: View {
    let existingThemes: [Theme]
    let onCreate: (Theme) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var themeName: String = ""
    @State private var copyFromTheme: Theme?

    var body: some View {
        VStack(spacing: 20) {
            Text("New Theme")
                .font(.headline)

            Form {
                Section {
                    TextField("Theme Name", text: $themeName)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Name")
                }

                Section {
                    Picker("Copy colors from", selection: $copyFromTheme) {
                        Text("None (use defaults)").tag(nil as Theme?)
                        ForEach(existingThemes) { theme in
                            Text(theme.name).tag(theme as Theme?)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Starting Colors")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createTheme()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(themeName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 350, height: 250)
        .onAppear {
            copyFromTheme = Theme.light
        }
    }

    private func createTheme() {
        let name = themeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let newTheme: Theme
        if let source = copyFromTheme {
            newTheme = source.duplicate(newName: name)
        } else {
            // Create with default light colors
            newTheme = Theme.light.duplicate(newName: name)
        }

        onCreate(newTheme)
        dismiss()
    }
}
