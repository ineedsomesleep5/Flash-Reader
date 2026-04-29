import SwiftUI

struct DocumentDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let documentID: ReadingDocument.ID
    @State private var showingDeleteConfirmation = false

    private var document: ReadingDocument? {
        model.document(with: documentID)
    }

    var body: some View {
        Group {
            if let document {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        titleBlock(document)
                        progressBlock(document)
                        previewBlock(document)
                        NavigationLink {
                            ReaderView(documentID: document.id)
                                .environmentObject(model)
                        } label: {
                            Label("Start Reading", systemImage: "play.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(FRTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
                .pageBackground()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                .alert("Delete document?", isPresented: $showingDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        model.delete(documentID: documentID)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes the document from Flash Reader.")
                }
            } else {
                ContentUnavailableView("Document missing", systemImage: "exclamationmark.triangle")
                    .pageBackground()
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func titleBlock(_ document: ReadingDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(document.title)
                .font(.system(.largeTitle, design: .rounded).weight(.black))
                .foregroundStyle(FRTheme.primaryText)
            Text("\(document.wordCount.formatted()) words - \(model.formattedETA(for: document))")
                .foregroundStyle(FRTheme.secondaryText)
        }
    }

    private func progressBlock(_ document: ReadingDocument) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RingProgressView(progress: document.percentComplete, label: "\(Int(document.percentComplete * 100))%")
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(document.progressIndex.formatted()) / \(document.wordCount.formatted())")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(FRTheme.primaryText)
                    Text("current position")
                        .font(.subheadline)
                        .foregroundStyle(FRTheme.secondaryText)
                }
                Spacer()
                Button("Reset") {
                    model.resetProgress(documentID: document.id)
                }
                .buttonStyle(.bordered)
                .tint(FRTheme.secondaryText)
            }
            ProgressView(value: document.percentComplete)
                .tint(FRTheme.accent)
        }
        .frCard()
    }

    private func previewBlock(_ document: ReadingDocument) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.headline)
                .foregroundStyle(FRTheme.primaryText)
            Text(previewText(document))
                .font(.body)
                .lineSpacing(5)
                .foregroundStyle(FRTheme.secondaryText)
        }
        .frCard()
    }

    private func previewText(_ document: ReadingDocument) -> AttributedString {
        let start = max(0, document.progressIndex - 20)
        let end = min(document.tokens.count, start + 140)
        var output = AttributedString("")
        for index in start..<end {
            var word = AttributedString(document.tokens[index].raw + " ")
            if index == document.progressIndex {
                word.foregroundColor = FRTheme.accent
                word.font = .body.bold()
            }
            output += word
        }
        return output
    }
}
