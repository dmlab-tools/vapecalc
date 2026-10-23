import SwiftUI
import VapeCalcCore

struct LibrarySidebar: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selection) {
            ForEach(store.visibleRecipes) { recipe in
                row(recipe)
                    .tag(recipe.id)
                    .contextMenu {
                        Button("Duplicate") { store.duplicate(id: recipe.id) }
                        Button("Delete", role: .destructive) { store.delete(id: recipe.id) }
                    }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button {
                    store.newDraft()
                } label: {
                    Label("New Recipe", systemImage: "plus")
                }
                .help("New Recipe (⌘N)")
                .disabled(store.isDraft)
            }
        }
        .searchable(text: $store.searchText, placement: .sidebar, prompt: "Search Recipes")
        .overlay {
            if store.library.isEmpty {
                ContentUnavailableView {
                    Label("No Saved Recipes", systemImage: "flask")
                } description: {
                    Text("Save the current mix to see it here.")
                }
            } else if store.visibleRecipes.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if store.recentlyDeleted != nil {
                    banner(Text("Recipe deleted"), action: "Undo") { store.undoDelete() }
                }
                if let error = store.storageError {
                    banner(Text(verbatim: error), tint: .orange)
                }
                Divider()
                HStack {
                    Button {
                        store.newDraft()
                    } label: {
                        Label("New Recipe", systemImage: "plus")
                            .font(.callout)
                    }
                    .buttonStyle(.borderless)
                    .disabled(store.isDraft)
                    .help("New Recipe (⌘N)")
                    Spacer()
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private func row(_ recipe: SavedRecipe) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(recipe.name)
                .lineLimit(1)
            Text(summary(recipe.input))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func summary(_ input: RecipeInput) -> String {
        let pg = Int(input.pgPercent)
        let volume = input.volumeMl.formatted(.number.precision(.fractionLength(0...1)))
        let nicotine = input.nicotineMgMl.formatted(.number.precision(.fractionLength(0...1)))
        return String(localized: "\(volume) ml · \(pg)/\(100 - pg) · \(nicotine) mg")
    }

    @ViewBuilder
    private func banner(
        _ text: Text,
        tint: Color = .secondary,
        action: LocalizedStringKey? = nil,
        perform: (() -> Void)? = nil
    ) -> some View {
        HStack {
            text
                .font(.callout)
                .foregroundStyle(tint)
                .lineLimit(2)
            Spacer()
            if let action, let perform {
                Button(action, action: perform)
                    .buttonStyle(.link)
            }
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}
