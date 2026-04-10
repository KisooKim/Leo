import SwiftUI
import AppKit

struct QuickAddView: View {
    @State private var keyword: String = ""
    @State private var title: String = ""
    @State private var type: ActionType = .openFolder
    @State private var path: String = ""
    @State private var command: String = ""
    @State private var urlTemplate: String = ""
    @State private var fallbackURL: String = ""
    @State private var errorMessage: String?

    var onSave: (Action) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add New Action")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                fieldRow(label: "Keyword") {
                    TextField("e.g. dl", text: $keyword)
                        .textFieldStyle(.roundedBorder)
                }

                fieldRow(label: "Title") {
                    TextField("e.g. Open Downloads", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                fieldRow(label: "Type") {
                    Picker("", selection: $type) {
                        Text("Folder").tag(ActionType.openFolder)
                        Text("File").tag(ActionType.openFile)
                        Text("Bash").tag(ActionType.runBash)
                        Text("Web Search").tag(ActionType.webSearch)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                typeSpecificFields()
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape)
                Button("Save") { attemptSave() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480, height: 400, alignment: .topLeading)
    }

    @ViewBuilder
    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func typeSpecificFields() -> some View {
        switch type {
        case .openFolder, .openFile:
            fieldRow(label: "Path") {
                HStack(spacing: 8) {
                    TextField("~/Downloads", text: $path)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…") { browse() }
                }
            }
        case .runBash:
            fieldRow(label: "Command") {
                TextField("echo hello", text: $command, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
        case .webSearch:
            fieldRow(label: "URL Template") {
                TextField("https://example.com/?q={query}", text: $urlTemplate)
                    .textFieldStyle(.roundedBorder)
            }
            fieldRow(label: "Fallback URL") {
                TextField("https://example.com (optional)", text: $fallbackURL)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = type == .openFile
        panel.canChooseDirectories = type == .openFolder
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }

    private func attemptSave() {
        let action = Action(
            keyword: keyword,
            title: title,
            type: type,
            path: type == .openFolder || type == .openFile ? path : nil,
            command: type == .runBash ? command : nil,
            urlTemplate: type == .webSearch ? urlTemplate : nil,
            fallbackURL: type == .webSearch && !fallbackURL.isEmpty ? fallbackURL : nil
        )
        do {
            try action.validate()
            errorMessage = nil
            onSave(action)
        } catch {
            errorMessage = "Invalid: \(error)"
        }
    }
}
