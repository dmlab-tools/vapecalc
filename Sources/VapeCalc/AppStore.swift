import Foundation
import Observation
import VapeCalcCore

/// Owns the library and the recipe currently being edited. Edits to a selected recipe are
/// written back immediately and flushed to disk shortly after, like Notes — there is no Save button.
@MainActor
@Observable
final class AppStore {
    var library: RecipeLibrary
    var editing: RecipeInput
    var searchText = ""
    private(set) var recentlyDeleted: SavedRecipe?
    private(set) var storageError: String?

    var selection: SavedRecipe.ID? {
        didSet {
            guard selection != oldValue else { return }
            flush()
            editing = selection.flatMap { library.recipe(id: $0)?.input } ?? RecipeInput()
        }
    }

    private let store: RecipeLibraryStore?
    private var pendingSave: Task<Void, Never>?

    init(store: RecipeLibraryStore?) {
        self.store = store
        self.editing = RecipeInput()

        do {
            library = try store?.load() ?? RecipeLibrary()
        } catch {
            library = RecipeLibrary()
            storageError = String(localized: "Library not loaded: \(error.localizedDescription)")
        }
    }

    static func makeDefault() -> AppStore {
        AppStore(store: (try? RecipeLibraryStore.defaultFileURL()).map { RecipeLibraryStore(fileURL: $0) })
    }

    var selectedRecipe: SavedRecipe? { selection.flatMap { library.recipe(id: $0) } }
    var isDraft: Bool { selection == nil }
    var visibleRecipes: [SavedRecipe] { library.filtered(by: searchText) }

    func editingDidChange() {
        guard let id = selection else { return }
        library.update(id: id, input: editing)
        schedulePersist()
    }

    func newDraft() {
        selection = nil
    }

    func saveDraft(name: String) {
        let recipe = library.add(name: name, input: editing)
        selection = recipe.id
        persist()
    }

    func rename(to name: String) {
        guard let id = selection else { return }
        library.rename(id: id, to: name)
        persist()
    }

    func duplicate(id: SavedRecipe.ID) {
        guard let copy = library.duplicate(id: id) else { return }
        selection = copy.id
        persist()
    }

    func makeVariant(volumeMl: Double, nicotineMgMl: Double) {
        guard let id = selection,
              let variant = library.variant(of: id, volumeMl: volumeMl, nicotineMgMl: nicotineMgMl)
        else { return }
        selection = variant.id
        persist()
    }

    func delete(id: SavedRecipe.ID) {
        guard let removed = library.remove(id: id) else { return }
        recentlyDeleted = removed
        if selection == id { selection = nil }
        persist()
        hideUndo(for: removed.id, after: .seconds(8))
    }

    func undoDelete() {
        guard let recipe = recentlyDeleted else { return }
        library.restore(recipe)
        recentlyDeleted = nil
        selection = recipe.id
        persist()
    }

    private func hideUndo(for id: SavedRecipe.ID, after delay: Duration) {
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard self?.recentlyDeleted?.id == id else { return }
            self?.recentlyDeleted = nil
        }
    }

    /// Writes any pending change right away — on selection switch and on quit.
    func flush() {
        guard pendingSave != nil else { return }
        pendingSave?.cancel()
        pendingSave = nil
        persist()
    }

    private func schedulePersist() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.pendingSave = nil
            self?.persist()
        }
    }

    private func persist() {
        guard let store else { return }
        do {
            try store.save(library)
            storageError = nil
        } catch {
            storageError = String(localized: "Library not saved: \(error.localizedDescription)")
        }
    }
}
