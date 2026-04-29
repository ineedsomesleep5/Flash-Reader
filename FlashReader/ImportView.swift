import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""
    @State private var message: String?
    @State private var showingFileImporter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bring in something worth focusing on.")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(FRTheme.primaryText)
                        Text("Paste text directly or import a text/Markdown file from Files.")
                            .foregroundStyle(FRTheme.secondaryText)
                    }
                    .frCard()

                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Title", text: $title)
                            .textFieldStyle(.roundedBorder)
                        TextEditor(text: $text)
                            .frame(minHeight: 220)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(FRTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(FRTheme.primaryText)
                        if let message {
                            Text(message)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(FRTheme.accent)
                        }
                    }
                    .frCard()

                    PrimaryActionButton(title: "Add to Library", systemImage: "text.badge.plus") {
                        addPastedText()
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Import .txt or .md", systemImage: "doc")
                            .font(.headline)
                            .foregroundStyle(FRTheme.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(FRTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .pageBackground()
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.plainText, .text, UTType(filenameExtension: "md") ?? .plainText],
                allowsMultipleSelection: false
            ) { result in
                importFile(result)
            }
        }
    }

    private func addPastedText() {
        do {
            _ = try model.addDocument(title: title, text: text)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            _ = try model.importFile(from: url)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}
