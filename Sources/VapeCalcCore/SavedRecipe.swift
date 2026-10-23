import Foundation

public struct SavedRecipe: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var input: RecipeInput
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        input: RecipeInput,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.input = input
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// The recipe collection with its CRUD, kept as a value type so it stays testable without a UI.
/// Recipes are always ordered by `updatedAt`, newest first.
public struct RecipeLibrary: Equatable, Sendable {
    public private(set) var recipes: [SavedRecipe]

    public init(recipes: [SavedRecipe] = []) {
        self.recipes = recipes
        sort()
    }

    public var isEmpty: Bool { recipes.isEmpty }

    public func recipe(id: SavedRecipe.ID) -> SavedRecipe? {
        recipes.first { $0.id == id }
    }

    public func filtered(by query: String) -> [SavedRecipe] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return recipes }
        return recipes.filter { $0.name.localizedCaseInsensitiveContains(needle) }
    }

    @discardableResult
    public mutating func add(name: String, input: RecipeInput, now: Date = Date()) -> SavedRecipe {
        let recipe = SavedRecipe(name: uniqueName(from: name), input: input, createdAt: now, updatedAt: now)
        recipes.append(recipe)
        sort()
        return recipe
    }

    public mutating func update(id: SavedRecipe.ID, input: RecipeInput, now: Date = Date()) {
        guard let index = recipes.firstIndex(where: { $0.id == id }), recipes[index].input != input else { return }
        recipes[index].input = input
        recipes[index].updatedAt = now
        sort()
    }

    public mutating func rename(id: SavedRecipe.ID, to name: String, now: Date = Date()) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let index = recipes.firstIndex(where: { $0.id == id }), !trimmed.isEmpty else { return }
        recipes[index].name = trimmed
        recipes[index].updatedAt = now
        sort()
    }

    /// Copies the recipe, flavour ids included: they only identify rows inside one recipe.
    @discardableResult
    public mutating func duplicate(id: SavedRecipe.ID, now: Date = Date()) -> SavedRecipe? {
        guard let source = recipe(id: id) else { return nil }
        return add(name: String(localized: "\(source.name) (copy)"), input: source.input, now: now)
    }

    /// Same proportions, different batch: percentages are unchanged, so the calculator rescales the ml.
    @discardableResult
    public mutating func variant(
        of id: SavedRecipe.ID,
        volumeMl: Double,
        nicotineMgMl: Double,
        now: Date = Date()
    ) -> SavedRecipe? {
        guard let source = recipe(id: id) else { return nil }
        var input = source.input
        input.volumeMl = volumeMl
        input.nicotineMgMl = nicotineMgMl

        let volume = format(volumeMl)
        let name = nicotineMgMl == source.input.nicotineMgMl
            ? String(localized: "\(source.name) (\(volume) ml)")
            : String(localized: "\(source.name) (\(volume) ml, \(format(nicotineMgMl)) mg)")
        return add(name: name, input: input, now: now)
    }

    @discardableResult
    public mutating func remove(id: SavedRecipe.ID) -> SavedRecipe? {
        guard let index = recipes.firstIndex(where: { $0.id == id }) else { return nil }
        return recipes.remove(at: index)
    }

    /// Puts a removed recipe back; ordering follows its untouched `updatedAt`.
    public mutating func restore(_ recipe: SavedRecipe) {
        guard !recipes.contains(where: { $0.id == recipe.id }) else { return }
        recipes.append(recipe)
        sort()
    }

    private mutating func sort() {
        recipes.sort { ($0.updatedAt, $0.name) > ($1.updatedAt, $1.name) }
    }

    private func uniqueName(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let base = trimmed.isEmpty ? String(localized: "Untitled") : trimmed
        guard recipes.contains(where: { $0.name == base }) else { return base }

        var counter = 2
        while recipes.contains(where: { $0.name == "\(base) \(counter)" }) {
            counter += 1
        }
        return "\(base) \(counter)"
    }

    private func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
