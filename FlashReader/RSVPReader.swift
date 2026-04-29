import Foundation

@MainActor
final class RSVPReader: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentChunk: [ReadingToken] = []
    @Published private(set) var currentIndex = 0

    private var tokens: [ReadingToken] = []
    private var wpm = ReaderSettings.defaults.wpm
    private var smartPauses = ReaderSettings.defaults.smartPauses
    private var chunkSize = ReaderSettings.defaults.chunkSize
    private var playbackTask: Task<Void, Never>?
    private var onAdvance: ((Int, [ReadingToken]) -> Void)?
    private var onEnd: (() -> Void)?

    deinit {
        playbackTask?.cancel()
    }

    func play(
        tokens: [ReadingToken],
        startIndex: Int,
        wpm: Int,
        smartPauses: Bool,
        chunkSize: Int,
        onAdvance: @escaping (Int, [ReadingToken]) -> Void,
        onEnd: @escaping () -> Void
    ) {
        guard !tokens.isEmpty else { return }
        pause()
        self.tokens = tokens
        self.wpm = max(1, wpm)
        self.smartPauses = smartPauses
        self.chunkSize = max(1, chunkSize)
        self.onAdvance = onAdvance
        self.onEnd = onEnd
        currentIndex = Self.clampedIndex(startIndex, tokenCount: tokens.count)
        currentChunk = Self.chunk(in: tokens, at: currentIndex, size: self.chunkSize)
        isPlaying = true
        emitCurrentChunk()
        playbackTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func pause() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }

    func seek(to index: Int) {
        guard !tokens.isEmpty else {
            currentIndex = 0
            currentChunk = []
            return
        }
        currentIndex = Self.clampedIndex(index, tokenCount: tokens.count)
        currentChunk = Self.chunk(in: tokens, at: currentIndex, size: chunkSize)
        emitCurrentChunk()
    }

    func setWPM(_ newValue: Int) {
        wpm = max(1, newValue)
    }

    func setChunkSize(_ newValue: Int) {
        chunkSize = max(1, newValue)
        currentChunk = Self.chunk(in: tokens, at: currentIndex, size: chunkSize)
    }

    func configurePreview(tokens: [ReadingToken], index: Int, chunkSize: Int) {
        self.tokens = tokens
        self.chunkSize = max(1, chunkSize)
        currentIndex = Self.clampedIndex(index, tokenCount: tokens.count)
        currentChunk = Self.chunk(in: tokens, at: currentIndex, size: self.chunkSize)
    }

    static func clampedIndex(_ index: Int, tokenCount: Int) -> Int {
        guard tokenCount > 0 else { return 0 }
        return min(max(0, index), tokenCount - 1)
    }

    static func chunk(in tokens: [ReadingToken], at index: Int, size: Int) -> [ReadingToken] {
        guard !tokens.isEmpty else { return [] }
        let start = clampedIndex(index, tokenCount: tokens.count)
        let end = min(tokens.count, start + max(1, size))
        return Array(tokens[start..<end])
    }

    static func delayForChunk(_ chunk: [ReadingToken], wpm: Int, smartPauses: Bool) -> TimeInterval {
        let multiplier = smartPauses ? chunk.map(\.timingMultiplier).max() ?? 1 : 1
        return (60.0 / Double(max(1, wpm))) * multiplier
    }

    private func runLoop() async {
        while !Task.isCancelled, isPlaying {
            let delay = Self.delayForChunk(currentChunk, wpm: wpm, smartPauses: smartPauses)
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            if Task.isCancelled { return }
            advance()
        }
    }

    private func advance() {
        guard !tokens.isEmpty else {
            finish()
            return
        }
        let nextIndex = currentIndex + chunkSize
        guard nextIndex < tokens.count else {
            currentIndex = tokens.count
            currentChunk = []
            finish()
            return
        }
        currentIndex = nextIndex
        currentChunk = Self.chunk(in: tokens, at: currentIndex, size: chunkSize)
        emitCurrentChunk()
    }

    private func finish() {
        pause()
        onEnd?()
    }

    private func emitCurrentChunk() {
        guard !currentChunk.isEmpty else { return }
        onAdvance?(currentIndex, currentChunk)
    }
}
