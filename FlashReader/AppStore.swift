import Foundation

final class AppStore {
    enum StoreError: LocalizedError {
        case cannotCreateDirectory(URL)

        var errorDescription: String? {
            switch self {
            case .cannotCreateDirectory(let url):
                return "Flash Reader could not create its storage folder at \(url.path)."
            }
        }
    }

    private let fileManager: FileManager
    private let directoryURL: URL
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        filename: String = "flash-reader-store.json"
    ) {
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            self.directoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("FlashReader", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FlashReader", isDirectory: true)
        }
        self.fileURL = self.directoryURL.appendingPathComponent(filename)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> AppSnapshot {
        guard fileManager.fileExists(atPath: fileURL.path) else { return .empty }
        let data = try Data(contentsOf: fileURL)
        let snapshot = try decoder.decode(AppSnapshot.self, from: data)
        return AppSnapshot(
            documents: snapshot.documents,
            settings: snapshot.settings.clamped,
            stats: snapshot.stats
        )
    }

    func save(_ snapshot: AppSnapshot) throws {
        guard ensureDirectoryExists() else {
            throw StoreError.cannotCreateDirectory(directoryURL)
        }
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func ensureDirectoryExists() -> Bool {
        if fileManager.fileExists(atPath: directoryURL.path) { return true }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }
}
