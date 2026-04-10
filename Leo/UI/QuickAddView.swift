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
        VStack(alignment: .leading, spacing: 12) {
            Text("Add New Action").font(.title2).bold()

            Form {
                TextField("Keyword", text: $keyword)
                TextField("Title", text: $title)

                Picker("Type", selection: $type) {
                    Text("Folder").tag(ActionType.openFolder)
                    Text("File").tag(ActionType.openFile)
                    Text("Bash").tag(ActionType.runBash)
                    Text("Web Search").tag(ActionType.webSearch)
                }

                switch type {
                case .openFolder, .openFile:
                    HStack {
                        TextField("Path", text: $path)
                        Button("Browse…") { browse() }
                    }
                case .runBash:
                    TextField("Command", text: $command, axis: .vertical)
                        .lineLimit(3...6)
                case .webSearch:
                    TextField("URL Template (use {query})", text: $urlTemplate,
                              prompt: Text("https://example.com/search?q={query}"))
                    TextField("Fallback URL (optional)", text: $fallbackURL)
                }
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.callout)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.escape)
                Button("Save") { attemptSave() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
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
            errorMessage = String(describing: error)
        }
    }
}
