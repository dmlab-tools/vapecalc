import Foundation

public enum RecipeLibraryError: Error, Equatable {
    /// The file was written by a newer build; refusing to read it keeps us from overwriting it.
    case unsupportedVersion(Int)
}

/// JSON file storage for the library. Writes are atomic and the format carries a version
/// so later field changes have a decode path instead of a flag day.
public struct RecipeLibraryStore {
    public static let currentVersion = 1

    public let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public static func defaultFileURL(
        bundleID: String = Bundle.main.bundleIdentifier ?? "com.vapecalc.desktop",
        fileManager: FileManager = .default
    ) throws -> URL {
        try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("library.json")
    }

    /// Returns an empty library when there is no file yet. A file that fails to decode is moved
    /// aside rather than dropped, so a bad write never silently eats the collection.
    public func load() throws -> RecipeLibrary {
        guard let data = fileManager.contents(atPath: fileURL.path) else { return RecipeLibrary() }

        do {
            let file = try Self.decoder.decode(LibraryFile.self, from: data)
            guard file.version <= Self.currentVersion else {
                throw RecipeLibraryError.unsupportedVersion(file.version)
            }
            return RecipeLibrary(recipes: file.recipes)
        } catch is DecodingError {
            try? moveAside()
            return RecipeLibrary()
        }
    }

    public func save(_ library: RecipeLibrary) throws {
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let file = LibraryFile(version: Self.currentVersion, recipes: library.recipes)
        try Self.encoder.encode(file).write(to: fileURL, options: .atomic)
    }

    private func moveAside() throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let target = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(stamp).json")
        try fileManager.moveItem(at: fileURL, to: target)
    }

    private struct LibraryFile: Codable {
        var version: Int
        var recipes: [SavedRecipe]
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
