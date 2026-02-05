import SwiftUI

struct ThemeEditorView: View {
    @Binding var theme: Theme
    let onSave: (Theme) -> Void

    var body: some View {
        ScrollView {
            Form {
                // Name section (only for custom themes)
                if !theme.isBuiltIn {
                    Section {
                        TextField("Theme Name", text: $theme.name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: theme.name) { _, _ in
                                onSave(theme)
                            }
                    } header: {
                        Text("Name")
                    }
                }

                // Terminal backgrounds
                Section {
                    ColorEditRow(
                        label: "Central Pane Terminal",
                        color: $theme.centralTerminalBackground,
                        disabled: theme.isBuiltIn,
                        onSave: { onSave(theme) }
                    )
                    ColorEditRow(
                        label: "Right Pane Terminal",
                        color: $theme.rightTerminalBackground,
                        disabled: theme.isBuiltIn,
                        onSave: { onSave(theme) }
                    )
                } header: {
                    Text("Terminal Backgrounds")
                }

                // Left pane
                Section {
                    ColorEditRow(
                        label: "Left Pane Background",
                        color: $theme.leftPaneBackground,
                        disabled: theme.isBuiltIn,
                        onSave: { onSave(theme) }
                    )
                    ColorEditRow(
                        label: "Workspace List",
                        color: $theme.leftWorkspaceListBackground,
                        disabled: theme.isBuiltIn,
                        onSave: { onSave(theme) }
                    )
                } header: {
                    Text("Left Pane")
                }

                // Right pane content
                Section {
                    ColorEditRow(
                        label: "File Manager",
                        color: $theme.rightFileManagerBackground,
                        disabled: theme.isBuiltIn,
                        onSave: { onSave(theme) }
                    )
                    ColorEditRow(
                        label: "Changes Pane",
                        color: $theme.rightChangesBackground,
                        disabled: theme.isBuiltIn,
                        onSave: { onSave(theme) }
                    )
                    ColorEditRow(
                        label: "Checks Pane",
                        color: $theme.rightChecksBackground,
                        disabled: theme.isBuiltIn,
                        onSave: { onSave(theme) }
                    )
                } header: {
                    Text("Right Pane Content")
                }

                // Toolbars
                Section {
                    ColorEditRow(
                        label: "Central Pane Toolbar",
                        color: $theme.centralToolbarBackground,
                        disabled: theme.isBuiltIn,
                        onSave: { onSave(theme) }
                    )
                    ColorEditRow(
                        label: "Right Pane Toolbars",
                        color: $theme.rightToolbarBackground,
                        disabled: theme.isBuiltIn,
                        onSave: { onSave(theme) }
                    )
                } header: {
                    Text("Toolbars")
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
        }
    }
}

struct ColorEditRow: View {
    let label: String
    @Binding var color: ThemeColor
    let disabled: Bool
    let onSave: () -> Void

    @State private var hexInput: String = ""
    @State private var pickerColor: Color = .white
    @State private var isValidHex: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(minWidth: 140, alignment: .leading)

            Spacer()

            // Hex text field
            TextField("Hex", text: $hexInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .disabled(disabled)
                .foregroundColor(isValidHex ? .primary : .red)
                .onChange(of: hexInput) { _, newValue in
                    validateAndApplyHex(newValue)
                }
                .onSubmit {
                    if ThemeColor.isValidHex(hexInput) {
                        color = ThemeColor(hex: hexInput)
                        pickerColor = color.color
                        onSave()
                    }
                }

            // Native color picker
            ColorPicker("", selection: $pickerColor)
                .labelsHidden()
                .disabled(disabled)
                .onChange(of: pickerColor) { _, newColor in
                    applyPickerColor(newColor)
                }

            // Preview swatch
            RoundedRectangle(cornerRadius: 4)
                .fill(color.color)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .onAppear {
            hexInput = color.hex
            pickerColor = color.color
        }
    }

    private func validateAndApplyHex(_ hex: String) {
        isValidHex = ThemeColor.isValidHex(hex) || hex.isEmpty || hex == "#"

        if ThemeColor.isValidHex(hex) {
            color = ThemeColor(hex: hex)
            pickerColor = color.color
            hexInput = color.hex  // Normalize format
            onSave()
        }
    }

    private func applyPickerColor(_ newColor: Color) {
        guard !disabled else { return }

        // Convert Color to NSColor
        if let nsColor = NSColor(newColor).usingColorSpace(.sRGB) {
            color = ThemeColor(nsColor: nsColor)
            hexInput = color.hex
            onSave()
        }
    }
}
