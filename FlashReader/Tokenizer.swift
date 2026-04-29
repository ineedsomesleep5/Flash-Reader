import Foundation

enum Tokenizer {
    static let sentenceEndMultiplier = 2.5
    static let clauseEndMultiplier = 1.5
    static let longWordMultiplier = 1.4
    static let mediumWordMultiplier = 1.2

    private static let boundaryCharacters = CharacterSet(charactersIn: ".,!?;:\"'`()[]{}-")
    private static let closingCharacters = CharacterSet(charactersIn: "\"'`)]}")

    static func tokenize(_ text: String) -> [ReadingToken] {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map(token)
    }

    static func token(from raw: String) -> ReadingToken {
        let stripped = strippedToken(raw)
        let length = stripped.count
        return ReadingToken(
            raw: raw,
            stripped: stripped,
            orpIndex: optimalRecognitionPoint(forLength: length),
            timingMultiplier: timingMultiplier(raw: raw, strippedLength: length)
        )
    }

    static func strippedToken(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: boundaryCharacters)
        return trimmed.isEmpty ? raw : trimmed
    }

    static func optimalRecognitionPoint(forLength length: Int) -> Int {
        if length <= 1 { return 0 }
        if length <= 5 { return 1 }
        if length <= 9 { return 2 }
        return 3
    }

    static func timingMultiplier(raw: String, strippedLength: Int) -> Double {
        if endsSentence(raw) { return sentenceEndMultiplier }
        if endsClause(raw) { return clauseEndMultiplier }
        if strippedLength > 12 { return longWordMultiplier }
        if strippedLength > 8 { return mediumWordMultiplier }
        return 1
    }

    static func endsSentence(_ raw: String) -> Bool {
        guard let last = significantTerminalCharacter(in: raw) else { return false }
        return ".!?".contains(last)
    }

    static func endsClause(_ raw: String) -> Bool {
        guard let last = significantTerminalCharacter(in: raw) else { return false }
        return ",;:".contains(last)
    }

    private static func significantTerminalCharacter(in raw: String) -> Character? {
        var scalars = raw.unicodeScalars
        while let last = scalars.last, closingCharacters.contains(last) {
            scalars.removeLast()
        }
        return scalars.last.map(Character.init)
    }
}
