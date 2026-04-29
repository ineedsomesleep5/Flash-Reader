import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum ImportError: LocalizedError {
        case emptyText
        case unsupportedFile
        case unreadableFile

        var errorDescription: String? {
            switch self {
            case .emptyText:
                return "Paste or choose text before adding it to your library."
            case .unsupportedFile:
                return "Flash Reader can import .txt and .md files in this build."
            case .unreadableFile:
                return "The selected file could not be read."
            }
        }
    }

    @Published private(set) var documents: [ReadingDocument] = []
    @Published var settings: ReaderSettings = .defaults {
        didSet {
            persist()
        }
    }
    @Published private(set) var stats: ReadingStats = .empty
    @Published var lastErrorMessage: String?

    private let store: AppStore

    init(store: AppStore = AppStore()) {
        self.store = store
        do {
            let snapshot = try store.load()
            documents = snapshot.documents
            settings = snapshot.settings.clamped
            stats = snapshot.stats
            seedIfNeeded()
        } catch {
            lastErrorMessage = error.localizedDescription
            seedIfNeeded()
        }
    }

    var sortedDocuments: [ReadingDocument] {
        documents.sorted { $0.lastReadAt > $1.lastReadAt }
    }

    var continueDocument: ReadingDocument? {
        sortedDocuments.first { $0.progressIndex > 0 && $0.progressIndex < max($0.wordCount - 1, 0) }
            ?? sortedDocuments.first
    }

    var todayWords: Int {
        stats.wordsRead(on: Date())
    }

    var dailyGoalProgress: Double {
        guard settings.dailyWordGoal > 0 else { return 0 }
        return min(1, Double(todayWords) / Double(settings.dailyWordGoal))
    }

    var streak: Int {
        stats.streakEnding()
    }

    func document(with id: ReadingDocument.ID) -> ReadingDocument? {
        documents.first { $0.id == id }
    }

    @discardableResult
    func addDocument(title: String, text: String) throws -> ReadingDocument {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { throw ImportError.emptyText }
        let tokens = Tokenizer.tokenize(cleanText)
        guard !tokens.isEmpty else { throw ImportError.emptyText }
        let document = ReadingDocument(title: title, text: cleanText, tokens: tokens)
        documents.insert(document, at: 0)
        persist()
        return document
    }

    @discardableResult
    func importFile(from url: URL) throws -> ReadingDocument {
        let supportedExtensions = ["txt", "md", "markdown"]
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ImportError.unsupportedFile
        }

        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw ImportError.unreadableFile
        }
        let title = url.deletingPathExtension().lastPathComponent
        return try addDocument(title: title, text: text)
    }

    func updateProgress(documentID: ReadingDocument.ID, index: Int) {
        guard let offset = documents.firstIndex(where: { $0.id == documentID }) else { return }
        let maxIndex = max(documents[offset].wordCount - 1, 0)
        documents[offset].progressIndex = min(max(0, index), maxIndex)
        documents[offset].lastReadAt = Date()
        persist()
    }

    func accumulateSession(documentID: ReadingDocument.ID, from startIndex: Int, to endIndex: Int, seconds: TimeInterval) {
        let wordsRead = max(0, endIndex - startIndex)
        stats.record(words: wordsRead, seconds: seconds)
        updateProgress(documentID: documentID, index: endIndex)
        persist()
    }

    func resetProgress(documentID: ReadingDocument.ID) {
        guard let offset = documents.firstIndex(where: { $0.id == documentID }) else { return }
        documents[offset].progressIndex = 0
        documents[offset].lastReadAt = Date()
        persist()
    }

    func delete(documentID: ReadingDocument.ID) {
        documents.removeAll { $0.id == documentID }
        persist()
    }

    func sentenceContext(for document: ReadingDocument, index: Int) -> String {
        guard !document.tokens.isEmpty else { return "" }
        let safeIndex = RSVPReader.clampedIndex(index, tokenCount: document.tokens.count)
        var start = safeIndex
        while start > 0, !Tokenizer.endsSentence(document.tokens[start - 1].raw) {
            start -= 1
        }

        var end = safeIndex
        while end < document.tokens.count - 1, !Tokenizer.endsSentence(document.tokens[end].raw) {
            end += 1
        }

        return document.tokens[start...end].map(\.raw).joined(separator: " ")
    }

    func formattedETA(for document: ReadingDocument) -> String {
        let minutes = document.estimatedMinutesLeft(wpm: settings.wpm)
        if minutes < 60 { return "\(minutes)m left" }
        return "\(minutes / 60)h \(minutes % 60)m left"
    }

    func updateSettings(_ edit: (inout ReaderSettings) -> Void) {
        var next = settings
        edit(&next)
        settings = next.clamped
    }

    func seedIfNeeded() {
        guard documents.isEmpty else { return }
        let text = """
        Welcome to Flash Reader. This app uses Rapid Serial Visual Presentation to show text one word at a time, reducing the eye movement that slows normal reading. The red letter marks the Optimal Recognition Point, the place your eye can rest while your brain recognizes the rest of the word.

        Start around 350 to 450 words per minute. If comprehension feels comfortable, raise the speed in small steps. If the words blur together, slow down and turn on sentence context. Consistency matters more than speed. A few focused minutes every day will train your rhythm.
        """
        _ = try? addDocument(title: "Start Here: How Flash Reader Works", text: text)
    }

    private func persist() {
        do {
            try store.save(AppSnapshot(documents: documents, settings: settings.clamped, stats: stats))
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
