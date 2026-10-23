import Foundation
import Testing
@testable import VapeCalcCore

private let now = Date(timeIntervalSince1970: 1_700_000_000)

private func makeInput(volume: Double = 30, flavour: String = "Strawberry") -> RecipeInput {
    RecipeInput(volumeMl: volume, flavours: [Flavour(name: flavour, percent: 5)])
}

@Test func addsAndOrdersByUpdatedAt() {
    var library = RecipeLibrary()
    library.add(name: "First", input: makeInput(), now: now)
    library.add(name: "Second", input: makeInput(), now: now.addingTimeInterval(60))

    #expect(library.recipes.map(\.name) == ["Second", "First"])
}

@Test func keepsNamesUnique() {
    var library = RecipeLibrary()
    library.add(name: "Mango", input: makeInput(), now: now)
    library.add(name: "Mango", input: makeInput(), now: now)
    library.add(name: "  ", input: makeInput(), now: now)

    #expect(library.recipes.map(\.name).sorted() == ["Mango", "Mango 2", "Untitled"])
}

@Test func updateTouchesTimestampOnlyOnRealChange() {
    var library = RecipeLibrary()
    // Reuse one value: a fresh RecipeInput() mints new flavour ids and would not compare equal.
    let input = makeInput()
    let recipe = library.add(name: "Mango", input: input, now: now)

    library.update(id: recipe.id, input: input, now: now.addingTimeInterval(60))
    #expect(library.recipe(id: recipe.id)?.updatedAt == now)

    var resized = input
    resized.volumeMl = 60
    library.update(id: recipe.id, input: resized, now: now.addingTimeInterval(60))
    #expect(library.recipe(id: recipe.id)?.input.volumeMl == 60)
    #expect(library.recipe(id: recipe.id)?.updatedAt == now.addingTimeInterval(60))
}

@Test func duplicatePreservesFlavourIdentity() {
    var library = RecipeLibrary()
    let source = library.add(name: "Mango", input: makeInput(), now: now)
    let copy = library.duplicate(id: source.id, now: now)

    #expect(copy?.name == "Mango (copy)")
    #expect(copy?.id != source.id)
    #expect(copy?.input.flavours.map(\.id) == source.input.flavours.map(\.id))
}

@Test func variantRescalesWithoutTouchingProportions() {
    var library = RecipeLibrary()
    let source = library.add(name: "Mango", input: makeInput(), now: now)
    let variant = library.variant(of: source.id, volumeMl: 60, nicotineMgMl: 6, now: now)

    #expect(variant?.name == "Mango (60 ml, 6 mg)")
    #expect(variant?.input.volumeMl == 60)
    #expect(variant?.input.flavours.first?.percent == 5)
    #expect(library.recipe(id: source.id)?.input.volumeMl == 30)

    let sameNicotine = library.variant(of: source.id, volumeMl: 100, nicotineMgMl: 3, now: now)
    #expect(sameNicotine?.name == "Mango (100 ml)")
}

@Test func removeAndRestoreRoundTrip() {
    var library = RecipeLibrary()
    let first = library.add(name: "First", input: makeInput(), now: now)
    library.add(name: "Second", input: makeInput(), now: now.addingTimeInterval(60))

    let removed = library.remove(id: first.id)
    #expect(removed?.name == "First")
    #expect(library.recipes.count == 1)

    library.restore(removed!)
    #expect(library.recipes.map(\.name) == ["Second", "First"])

    library.restore(removed!)
    #expect(library.recipes.count == 2)
}

/// Cyrillic names on purpose: case-insensitive search must work beyond ASCII.
@Test func filtersByNameCaseInsensitively() {
    var library = RecipeLibrary()
    library.add(name: "Манго лёд", input: makeInput(), now: now)
    library.add(name: "Табак", input: makeInput(), now: now)
    library.add(name: "Mango Ice", input: makeInput(), now: now)

    #expect(library.filtered(by: "манго").map(\.name) == ["Манго лёд"])
    #expect(library.filtered(by: "MANGO").map(\.name) == ["Mango Ice"])
    #expect(library.filtered(by: "  ").count == 3)
}

@Test func fileStoreRoundTrip() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = RecipeLibraryStore(fileURL: directory.appendingPathComponent("library.json"))

    #expect(try store.load().isEmpty)

    var library = RecipeLibrary()
    library.add(name: "Mango", input: makeInput(), now: now)
    try store.save(library)

    let loaded = try store.load()
    #expect(loaded.recipes.map(\.name) == ["Mango"])
    #expect(loaded.recipes.first?.input.flavours.first?.id == library.recipes.first?.input.flavours.first?.id)
    #expect(loaded.recipes.first?.updatedAt == now)
}

@Test func corruptFileIsMovedAsideInsteadOfCrashing() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("library.json")
    try Data("{ not json".utf8).write(to: fileURL)

    let store = RecipeLibraryStore(fileURL: fileURL)
    #expect(try store.load().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(leftovers.count == 1 && leftovers[0].contains("corrupt"))
}

@Test func refusesToReadNewerFormat() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("library.json")
    try Data(#"{"version": 99, "recipes": []}"#.utf8).write(to: fileURL)

    let store = RecipeLibraryStore(fileURL: fileURL)
    #expect(throws: RecipeLibraryError.unsupportedVersion(99)) { try store.load() }
    #expect(FileManager.default.fileExists(atPath: fileURL.path))
}
