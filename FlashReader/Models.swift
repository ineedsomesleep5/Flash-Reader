import Foundation

struct ReadingToken: Codable, Equatable, Hashable {
    let raw: String
    let stripped: String
    let orpIndex: Int
    let timingMultiplier: Double
}

struct ReadingDocument: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var text: String
    var tokens: [ReadingToken]
    var progressIndex: Int
    var addedAt: Date
    var lastReadAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        text: String,
        tokens: [ReadingToken],
        progressIndex: Int = 0,
        addedAt: Date = Date(),
        lastReadAt: Date = Date()
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : title
        self.text = text
        self.tokens = tokens
        self.progressIndex = max(0, min(progressIndex, max(tokens.count - 1, 0)))
        self.addedAt = addedAt
        self.lastReadAt = lastReadAt
    }

    var wordCount: Int { tokens.count }
    var wordsRemaining: Int { max(0, wordCount - progressIndex) }

    var percentComplete: Double {
        guard wordCount > 0 else { return 0 }
        return min(1, max(0, Double(progressIndex) / Double(wordCount)))
    }

    func estimatedMinutesLeft(wpm: Int) -> Int {
        guard wpm > 0 else { return 0 }
        return max(1, Int(ceil(Double(wordsRemaining) / Double(wpm))))
    }
}

struct ReaderSettings: Codable, Equatable {
    var wpm: Int
    var fontScale: Double
    var smartPauses: Bool
    var chunkSize: Int
    var showsContext: Bool
    var hapticsEnabled: Bool
    var dailyWordGoal: Int
    var tapToPlayEnabled: Bool

    static let defaults = ReaderSettings(
        wpm: 450,
        fontScale: 1.0,
        smartPauses: true,
        chunkSize: 1,
        showsContext: true,
        hapticsEnabled: true,
        dailyWordGoal: 2500,
        tapToPlayEnabled: true
    )

    var clamped: ReaderSettings {
        ReaderSettings(
            wpm: min(1000, max(100, wpm)),
            fontScale: min(1.45, max(0.8, fontScale)),
            smartPauses: smartPauses,
            chunkSize: min(3, max(1, chunkSize)),
            showsContext: showsContext,
            hapticsEnabled: hapticsEnabled,
            dailyWordGoal: min(20000, max(250, dailyWordGoal)),
            tapToPlayEnabled: tapToPlayEnabled
        )
    }
}

struct DailyReadingSession: Codable, Equatable, Identifiable {
    var id: UUID
    var date: Date
    var wordsRead: Int
    var secondsRead: TimeInterval

    init(id: UUID = UUID(), date: Date = Date(), wordsRead: Int, secondsRead: TimeInterval) {
        self.id = id
        self.date = date
        self.wordsRead = max(0, wordsRead)
        self.secondsRead = max(0, secondsRead)
    }
}

struct ReadingStats: Codable, Equatable {
    var totalWordsRead: Int
    var totalSecondsRead: TimeInterval
    var sessions: [DailyReadingSession]

    static let empty = ReadingStats(totalWordsRead: 0, totalSecondsRead: 0, sessions: [])

    mutating func record(words: Int, seconds: TimeInterval, date: Date = Date()) {
        let safeWords = max(0, words)
        let safeSeconds = max(0, seconds)
        guard safeWords > 0 || safeSeconds > 0 else { return }
        totalWordsRead += safeWords
        totalSecondsRead += safeSeconds
        sessions.append(DailyReadingSession(date: date, wordsRead: safeWords, secondsRead: safeSeconds))
    }

    func wordsRead(on date: Date, calendar: Calendar = .current) -> Int {
        sessions
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.wordsRead }
    }

    func streakEnding(on date: Date = Date(), calendar: Calendar = .current) -> Int {
        var streak = 0
        var current = calendar.startOfDay(for: date)
        while sessions.contains(where: { calendar.isDate($0.date, inSameDayAs: current) && $0.wordsRead > 0 }) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = previous
        }
        return streak
    }
}

struct AppSnapshot: Codable, Equatable {
    var documents: [ReadingDocument]
    var settings: ReaderSettings
    var stats: ReadingStats

    static let empty = AppSnapshot(documents: [], settings: .defaults, stats: .empty)
}
