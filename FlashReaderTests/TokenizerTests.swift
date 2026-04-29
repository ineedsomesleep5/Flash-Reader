import XCTest
@testable import FlashReader

final class TokenizerTests: XCTestCase {
    func testTokenizeSplitsOnWhitespace() {
        let tokens = Tokenizer.tokenize("Read faster\nwith focus")

        XCTAssertEqual(tokens.map(\.raw), ["Read", "faster", "with", "focus"])
    }

    func testStripsBoundaryPunctuation() {
        let token = Tokenizer.token(from: "(attention,)")

        XCTAssertEqual(token.stripped, "attention")
    }

    func testOptimalRecognitionPointRules() {
        XCTAssertEqual(Tokenizer.optimalRecognitionPoint(forLength: 1), 0)
        XCTAssertEqual(Tokenizer.optimalRecognitionPoint(forLength: 5), 1)
        XCTAssertEqual(Tokenizer.optimalRecognitionPoint(forLength: 9), 2)
        XCTAssertEqual(Tokenizer.optimalRecognitionPoint(forLength: 10), 3)
    }

    func testTimingMultipliersMatchPrototype() {
        XCTAssertEqual(Tokenizer.token(from: "Done.").timingMultiplier, 2.5)
        XCTAssertEqual(Tokenizer.token(from: "clause,").timingMultiplier, 1.5)
        XCTAssertEqual(Tokenizer.token(from: "extraordinarily").timingMultiplier, 1.4)
        XCTAssertEqual(Tokenizer.token(from: "attention").timingMultiplier, 1.2)
        XCTAssertEqual(Tokenizer.token(from: "read").timingMultiplier, 1.0)
    }
}
