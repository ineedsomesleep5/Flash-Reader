import XCTest
@testable import FlashReader

@MainActor
final class RSVPReaderTests: XCTestCase {
    func testChunkClampsAndSlices() {
        let tokens = Tokenizer.tokenize("one two three four")

        XCTAssertEqual(RSVPReader.chunk(in: tokens, at: -8, size: 2).map(\.raw), ["one", "two"])
        XCTAssertEqual(RSVPReader.chunk(in: tokens, at: 2, size: 2).map(\.raw), ["three", "four"])
        XCTAssertEqual(RSVPReader.chunk(in: tokens, at: 20, size: 2).map(\.raw), ["four"])
    }

    func testDelayUsesHighestChunkMultiplierWhenSmartPausesAreEnabled() {
        let chunk = [Tokenizer.token(from: "ordinary"), Tokenizer.token(from: "ending.")]

        XCTAssertEqual(RSVPReader.delayForChunk(chunk, wpm: 600, smartPauses: true), 0.25, accuracy: 0.0001)
        XCTAssertEqual(RSVPReader.delayForChunk(chunk, wpm: 600, smartPauses: false), 0.1, accuracy: 0.0001)
    }

    func testSeekClampsProgress() {
        let reader = RSVPReader()
        let tokens = Tokenizer.tokenize("one two three")

        reader.configurePreview(tokens: tokens, index: 99, chunkSize: 1)

        XCTAssertEqual(reader.currentIndex, 2)
        XCTAssertEqual(reader.currentChunk.map(\.raw), ["three"])
    }
}
