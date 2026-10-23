import SwiftUI
import VapeCalcCore

@main
struct VapeCalcApp: App {
    @State private var store = AppStore.makeDefault()

    var body: some Scene {
        WindowGroup("E-Liquid Calculator") {
            NavigationSplitView {
                LibrarySidebar()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            } detail: {
                RecipeDetailView()
            }
            .environment(store)
        }
        .defaultSize(width: 1180, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Recipe") { store.newDraft() }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .pasteboard) {
                Button("Duplicate") {
                    if let id = store.selection { store.duplicate(id: id) }
                }
                .keyboardShortcut("d")
                .disabled(store.selection == nil)

                Button("Delete Recipe") {
                    if let id = store.selection { store.delete(id: id) }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(store.selection == nil)

                Button("Undo Delete") { store.undoDelete() }
                    .keyboardShortcut("z")
                    .disabled(store.recentlyDeleted == nil)
            }
        }
    }
}
