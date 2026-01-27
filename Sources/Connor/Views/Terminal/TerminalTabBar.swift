import SwiftUI

struct TerminalTabBar: View {
    @Binding var terminals: [TerminalSessionState]
    @Binding var selectedTerminalId: UUID?
    let onAddTerminal: () -> Void
    let onCloseTerminal: (UUID) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Terminal tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(terminals) { terminal in
                        TerminalTab(
                            terminal: terminal,
                            isSelected: selectedTerminalId == terminal.id,
                            onSelect: {
                                selectedTerminalId = terminal.id
                            },
                            onClose: {
                                onCloseTerminal(terminal.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer()

            // Add terminal button
            Button(action: onAddTerminal) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("New Terminal")
            .padding(.trailing, 8)
        }
        .frame(height: 32)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct TerminalTab: View {
    @ObservedObject var terminal: TerminalSessionState
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Text(terminal.title)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .lineLimit(1)

            if isHovering || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.2))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
        )
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var terminals = [
            TerminalSessionState(title: "Terminal 1"),
            TerminalSessionState(title: "Terminal 2"),
        ]
        @State var selectedId: UUID?

        var body: some View {
            TerminalTabBar(
                terminals: $terminals,
                selectedTerminalId: $selectedId,
                onAddTerminal: {
                    terminals.append(TerminalSessionState(title: "Terminal \(terminals.count + 1)"))
                },
                onCloseTerminal: { id in
                    terminals.removeAll { $0.id == id }
                }
            )
        }
    }

    return PreviewWrapper()
        .frame(width: 400)
}
