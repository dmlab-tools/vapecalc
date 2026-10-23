import Testing
@testable import VapeCalcCore

@Test func bundledCatalogLoads() {
    let catalog = FlavorCatalog.shared
    #expect(catalog.suggestions.count > 5000)
    #expect(catalog.suggestions.allSatisfy { $0.percent > 0 && $0.percent <= 30 })
    #expect(catalog.suggestions.allSatisfy { !$0.name.isEmpty })
}

@Test func matchesRankPrefixAndPopularityFirst() {
    let catalog = FlavorCatalog.shared
    let matches = catalog.matches(for: "strawberry")
    #expect(!matches.isEmpty)
    #expect(matches.allSatisfy { $0.displayName.lowercased().contains("strawberry") })
    #expect(matches.first?.recipeCount ?? 0 > 1000)
}

@Test func matchesCombineBrandAndName() {
    let catalog = FlavorCatalog.shared
    let matches = catalog.matches(for: "cap vanilla custard")
    #expect(matches.first?.abbreviation == "CAP")
    #expect(matches.first?.name.contains("Vanilla Custard") == true)
}

/// A brand abbreviation must beat the same letters sitting inside a flavour name ("Captain").
@Test func brandAbbreviationOutranksSubstringHit() {
    let matches = FlavorCatalog.shared.matches(for: "cap vanilla")
    #expect(matches.first?.abbreviation == "CAP")
}

@Test func nameStartMatchLeadsTheList() {
    let matches = FlavorCatalog.shared.matches(for: "bavarian")
    #expect(matches.first?.name.hasPrefix("Bavarian") == true)
}

@Test func shortQueriesReturnNothing() {
    #expect(FlavorCatalog.shared.matches(for: "s").isEmpty)
    #expect(FlavorCatalog.shared.matches(for: " ").isEmpty)
}

@Test func lookupByDisplayNameGivesDosageHint() {
    let catalog = FlavorCatalog.shared
    let entry = catalog.entry(named: "TPA Bavarian Cream")
    #expect(entry?.percent == 2.2)
    #expect(entry?.range == 1.25...3.0)
    #expect(catalog.entry(named: "Flavour 1") == nil)
}

@Test func emptyCatalogIsHarmless() {
    let catalog = FlavorCatalog(suggestions: [])
    #expect(catalog.isEmpty)
    #expect(catalog.matches(for: "strawberry").isEmpty)
    #expect(catalog.entry(named: "TPA Strawberry") == nil)
}
