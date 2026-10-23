import Foundation

public struct FlavorSuggestion: Identifiable, Equatable, Sendable {
    public let id: Int
    public let brand: String
    public let abbreviation: String?
    public let name: String
    /// Typical dosage across the recipes that use the flavour.
    public let percent: Double
    public let range: ClosedRange<Double>?
    public let recipeCount: Int

    /// "TPA Strawberry, Ripe" — the spelling mixers use, falling back to the full brand name.
    public var displayName: String {
        "\(abbreviation ?? brand) \(name)"
    }
}

/// The bundled flavour list: names for autocomplete and a dosage hint per flavour.
public struct FlavorCatalog: Sendable {
    public static let shared = FlavorCatalog.bundled()

    public let suggestions: [FlavorSuggestion]
    private let haystack: [String]

    public var isEmpty: Bool { suggestions.isEmpty }

    public init(suggestions: [FlavorSuggestion]) {
        self.suggestions = suggestions.sorted { $0.recipeCount > $1.recipeCount }
        self.haystack = self.suggestions.map { "\($0.abbreviation ?? "") \($0.brand) \($0.name)".lowercased() }
    }

    static func bundled() -> FlavorCatalog {
        guard let url = resourceURL(),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(CatalogFile.self, from: data)
        else { return FlavorCatalog(suggestions: []) }

        let suggestions = file.flavors.enumerated().compactMap { index, entry -> FlavorSuggestion? in
            guard file.brands.indices.contains(entry.b) else { return nil }
            let brand = file.brands[entry.b]
            var range: ClosedRange<Double>?
            if let low = entry.lo, let high = entry.hi, low <= high {
                range = low...high
            }
            return FlavorSuggestion(
                id: index,
                brand: brand.name,
                abbreviation: brand.abbr,
                name: entry.n,
                percent: entry.p,
                range: range,
                recipeCount: entry.c
            )
        }
        return FlavorCatalog(suggestions: suggestions)
    }

    /// `Bundle.module` traps when the resource bundle is missing, which would take the app down
    /// over a suggestion list. Look the bundle up by hand and degrade to an empty catalogue instead.
    private static func resourceURL() -> URL? {
        let bundleName = "VapeCalc_VapeCalcCore.bundle"
        let hosts = [Bundle.main, Bundle(for: BundleToken.self)]
        var roots = hosts.flatMap { host -> [URL] in
            [host.resourceURL, host.bundleURL, host.bundleURL.deletingLastPathComponent()].compactMap { $0 }
        }
        roots.append(URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent())

        for root in roots {
            if let bundle = Bundle(url: root.appendingPathComponent(bundleName)),
               let url = bundle.url(forResource: "flavors", withExtension: "json") {
                return url
            }
        }
        return Bundle.main.url(forResource: "flavors", withExtension: "json")
    }

    /// Every query word must appear somewhere in the entry. Ranking puts a matching brand
    /// abbreviation and a name that starts with the query ahead of an incidental substring hit,
    /// then falls back to how many recipes use the flavour.
    public func matches(for query: String, limit: Int = 8) -> [FlavorSuggestion] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard needle.count >= 2 else { return [] }
        let words = needle.split(separator: " ").map(String.init)

        var scored: [(suggestion: FlavorSuggestion, score: Int)] = []
        for (index, text) in haystack.enumerated() where words.allSatisfy({ text.contains($0) }) {
            let suggestion = suggestions[index]
            let name = suggestion.name.lowercased()
            var score = 0
            if name.hasPrefix(needle) { score += 8 }
            if name.hasPrefix(words[0]) { score += 4 }
            if let abbreviation = suggestion.abbreviation?.lowercased(), words.contains(abbreviation) { score += 3 }
            if words.contains(where: { suggestion.brand.lowercased().hasPrefix($0) }) { score += 2 }
            scored.append((suggestion, score))
        }

        return scored
            .sorted { ($0.score, $0.suggestion.recipeCount) > ($1.score, $1.suggestion.recipeCount) }
            .prefix(limit)
            .map(\.suggestion)
    }

    /// The catalogue entry a typed name refers to, used for the dosage hint.
    public func entry(named name: String) -> FlavorSuggestion? {
        let needle = Self.normalize(name)
        guard !needle.isEmpty else { return nil }
        return suggestions.first { Self.normalize($0.displayName) == needle }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private final class BundleToken {}

    private struct CatalogFile: Decodable {
        struct Brand: Decodable {
            let name: String
            let abbr: String?
        }
        struct Entry: Decodable {
            let b: Int
            let n: String
            let p: Double
            let c: Int
            let lo: Double?
            let hi: Double?
        }
        let version: Int
        let brands: [Brand]
        let flavors: [Entry]
    }
}
