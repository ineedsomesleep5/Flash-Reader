import XCTest
@testable import FlashReader

final class AppStoreTests: XCTestCase {
    func testLoadReturnsDefaultsWhenNoFileExists() throws {
        let directory = temporaryDirectory()
        let store = AppStore(directoryURL: directory)

        let snapshot = try store.load()

        XCTAssertEqual(snapshot, .empty)
    }

    func testSaveAndLoadRoundTrip() throws {
        let directory = temporaryDirectory()
        let store = AppStore(directoryURL: directory)
        let document = ReadingDocument(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Sample",
            text: "Sample text.",
            tokens: Tokenizer.tokenize("Sample text."),
            progressIndex: 1,
            addedAt: Date(timeIntervalSince1970: 100),
            lastReadAt: Date(timeIntervalSince1970: 200)
        )
        let snapshot = AppSnapshot(
            documents: [document],
            settings: .defaults,
            stats: ReadingStats(totalWordsRead: 2, totalSecondsRead: 12, sessions: [])
        )

        try store.save(snapshot)
        let loaded = try store.load()

        XCTAssertEqual(loaded, snapshot)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("FlashReaderTests-\(UUID().uuidString)", isDirectory: true)
    }
}
