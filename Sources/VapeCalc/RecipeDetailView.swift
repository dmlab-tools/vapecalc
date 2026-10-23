import AppKit
import SwiftUI
import VapeCalcCore

struct RecipeDetailView: View {
    @Environment(AppStore.self) private var store
    @State private var name = ""
    @State private var showingVariant = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            header
            Divider()
            CalculatorView(input: $store.editing)
        }
        .onChange(of: store.editing) { store.editingDidChange() }
        .onChange(of: store.selection) { syncName() }
        .onChange(of: nameFocused) { _, focused in
            if !focused { commitName() }
        }
        .onAppear { syncName() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            commitName()
            store.flush()
        }
        .sheet(isPresented: $showingVariant) {
            if let recipe = store.selectedRecipe {
                VariantSheet(source: recipe) { volume, nicotine in
                    store.makeVariant(volumeMl: volume, nicotineMgMl: nicotine)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            TextField("Recipe Name", text: $name)
                .textFieldStyle(.plain)
                .font(.title2.bold())
                .focused($nameFocused)
                .onSubmit { commitName() }
                .frame(maxWidth: 420, alignment: .leading)

            Spacer()

            if store.isDraft {
                Text("Draft")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Save as Recipe") { store.saveDraft(name: name) }
                    .keyboardShortcut("s")
            } else {
                Button("Variant…") { showingVariant = true }
                Menu {
                    Button("New Recipe") { store.newDraft() }
                    Divider()
                    Button("Duplicate") { duplicate() }
                    Button("Delete", role: .destructive) { delete() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 40)
                .accessibilityLabel("More")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func syncName() {
        name = store.selectedRecipe?.name ?? ""
    }

    private func commitName() {
        guard !store.isDraft, let current = store.selectedRecipe, name != current.name else { return }
        store.rename(to: name)
        syncName()
    }

    private func duplicate() {
        guard let id = store.selection else { return }
        store.duplicate(id: id)
    }

    private func delete() {
        guard let id = store.selection else { return }
        store.delete(id: id)
    }
}
