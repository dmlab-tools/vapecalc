import SwiftUI
import VapeCalcCore

/// Copies a recipe at a different batch size or strength. Percentages stay put, so the
/// calculator simply rescales the millilitres.
struct VariantSheet: View {
    let source: SavedRecipe
    let onCreate: (Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var volumeMl: Double
    @State private var nicotineMgMl: Double

    init(source: SavedRecipe, onCreate: @escaping (Double, Double) -> Void) {
        self.source = source
        self.onCreate = onCreate
        _volumeMl = State(initialValue: source.input.volumeMl)
        _nicotineMgMl = State(initialValue: source.input.nicotineMgMl)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Variant of “\(source.name)”")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 20) {
                NumberField(
                    title: "Volume (ml)",
                    value: $volumeMl,
                    range: RecipeLimits.volume,
                    step: 5
                )
                NumberField(
                    title: "Nicotine (mg/ml)",
                    value: $nicotineMgMl,
                    range: RecipeLimits.nicotine,
                    step: 0.5
                )
            }

            Text("Proportions and flavours stay the same; only the millilitres are recalculated.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Create") {
                    onCreate(volumeMl, nicotineMgMl)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
