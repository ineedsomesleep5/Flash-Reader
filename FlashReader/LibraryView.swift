import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var searchText = ""
    @State private var showingImport = false
    @State private var showingSettings = false

    private var filteredDocuments: [ReadingDocument] {
        let docs = model.sortedDocuments
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return docs }
        return docs.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statsGrid
                    if let document = model.continueDocument {
                        continueCard(document)
                    }
                    documentList
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .pageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingImport) {
                ImportView()
                    .environmentObject(model)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(model)
            }
            .alert("Flash Reader", isPresented: Binding(
                get: { model.lastErrorMessage != nil },
                set: { if !$0 { model.lastErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { model.lastErrorMessage = nil }
            } message: {
                Text(model.lastErrorMessage ?? "")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Flash Reader")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(FRTheme.primaryText)
                Text("Train focus. Read faster.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(FRTheme.secondaryText)
            }
            Spacer()
            HStack(spacing: 10) {
                IconCircleButton(systemImage: "plus", accessibilityLabel: "Import") {
                    showingImport = true
                }
                IconCircleButton(systemImage: "slider.horizontal.3", accessibilityLabel: "Settings") {
                    showingSettings = true
                }
            }
        }
    }

    private var statsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(value: compact(model.stats.totalWordsRead), label: "words read", tint: FRTheme.accent)
                StatTile(value: readingTime, label: "focus time", tint: FRTheme.gold)
                StatTile(value: "\(model.streak)", label: "day streak", tint: FRTheme.mint)
            }
            HStack(spacing: 14) {
                RingProgressView(
                    progress: model.dailyGoalProgress,
                    label: "\(Int(model.dailyGoalProgress * 100))%"
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's goal")
                        .font(.headline)
                        .foregroundStyle(FRTheme.primaryText)
                    Text("\(model.todayWords.formatted()) of \(model.settings.dailyWordGoal.formatted()) words")
                        .font(.subheadline)
                        .foregroundStyle(FRTheme.secondaryText)
                    ProgressView(value: model.dailyGoalProgress)
                        .tint(FRTheme.accent)
                }
            }
            .frCard()
        }
    }

    private func continueCard(_ document: ReadingDocument) -> some View {
        NavigationLink {
            ReaderView(documentID: document.id)
                .environmentObject(model)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Label("Continue Reading", systemImage: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FRTheme.gold)
                Text(document.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(FRTheme.primaryText)
                    .lineLimit(2)
                HStack {
                    Text(model.formattedETA(for: document))
                    Spacer()
                    Text("\(document.wordCount.formatted()) words")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(FRTheme.secondaryText)
                ProgressView(value: document.percentComplete)
                    .tint(FRTheme.accent)
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [FRTheme.elevated, FRTheme.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(FRTheme.accent.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }

    private var documentList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Library")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(FRTheme.primaryText)
                Spacer()
                Text("\(filteredDocuments.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FRTheme.secondaryText)
            }
            TextField("Search documents", text: $searchText)
                .textInputAutocapitalization(.never)
                .padding(14)
                .background(FRTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(FRTheme.primaryText)
            if filteredDocuments.isEmpty {
                ContentUnavailableView("No documents", systemImage: "text.page", description: Text("Import text or Markdown to start reading."))
                    .foregroundStyle(FRTheme.secondaryText)
                    .frCard()
            } else {
                ForEach(filteredDocuments) { document in
                    NavigationLink {
                        DocumentDetailView(documentID: document.id)
                            .environmentObject(model)
                    } label: {
                        DocumentRow(document: document, eta: model.formattedETA(for: document))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var readingTime: String {
        let minutes = Int(model.stats.totalSecondsRead / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }

    private func compact(_ value: Int) -> String {
        value >= 1000 ? String(format: "%.1fk", Double(value) / 1000) : "\(value)"
    }
}

#Preview {
    LibraryView()
        .environmentObject(AppModel(store: AppStore(directoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-library"))))
}
