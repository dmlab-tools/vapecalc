import SwiftUI
import VapeCalcCore

struct CalculatorView: View {
    @Binding var input: RecipeInput

    @FocusState private var focusedFlavour: Flavour.ID?
    @State private var highlighted = 0

    private var result: RecipeResult { RecipeCalculator.calculate(input) }

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ratioBlock
                    volumeBlock
                    nicotineBlock
                    flavoursBlock
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 480, idealWidth: 560)

            RecipeTable(result: result)
                .frame(minWidth: 340, idealWidth: 380)
        }
        .frame(minHeight: 560)
    }

    private var ratioBlock: some View {
        Block("PG / VG ratio") {
            HStack {
                Text(verbatim: "\(Int(input.pgPercent)) % PG")
                    .foregroundStyle(.blue)
                Spacer()
                Text(verbatim: "\(Int(100 - input.pgPercent)) % VG")
                    .foregroundStyle(.green)
            }
            .font(.headline.monospacedDigit())

            Slider(value: $input.pgPercent, in: 0...100, step: 5)
                .help("Drag the slider to set the PG / VG ratio you want.")
        }
    }

    private var volumeBlock: some View {
        Block("Volume") {
            NumberField(
                title: "Final liquid volume (ml)",
                value: $input.volumeMl,
                range: RecipeLimits.volume,
                step: 5,
                help: "How many ml of finished liquid you want to make."
            )
        }
    }

    private var nicotineBlock: some View {
        Block("Nicotine") {
            Text("Nicotine base strength (mg/ml)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Picker("Strength", selection: $input.nicBaseStrength) {
                    ForEach(RecipeLimits.nicBasePresets, id: \.self) {
                        Text(verbatim: "\(Int($0))").tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                TextField("mg/ml", value: $input.nicBaseStrength, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onChange(of: input.nicBaseStrength) { _, new in
                        let clamped = min(max(new, RecipeLimits.nicBaseStrength.lowerBound),
                                          RecipeLimits.nicBaseStrength.upperBound)
                        if clamped != new { input.nicBaseStrength = clamped }
                    }

                CarrierPicker(carrier: $input.nicBaseCarrier)
                Spacer()
            }
            .help("Strength of your nicotine base in mg/ml and its carrier: PG or VG.")

            Divider().padding(.vertical, 4)

            NumberField(
                title: "Nicotine in the liquid (mg/ml)",
                value: $input.nicotineMgMl,
                range: RecipeLimits.nicotine,
                step: 0.5,
                help: "Nicotine strength (mg/ml) you want in the finished liquid."
            )
        }
    }

    private var flavoursBlock: some View {
        Block("Flavours (%)") {
            ForEach($input.flavours) { $flavour in
                VStack(alignment: .leading, spacing: 4) {
                    flavourRow($flavour)
                    if isSuggesting(flavour) {
                        suggestionList(for: $flavour)
                    }
                }
            }

            Button {
                input.flavours.append(
                    Flavour(name: String(localized: "Flavour \(input.flavours.count + 1)"), percent: 0)
                )
            } label: {
                Label("Add Flavour", systemImage: "plus")
            }
            .padding(.top, 4)
        }
    }

    private func flavourRow(_ flavour: Binding<Flavour>) -> some View {
        HStack(spacing: 10) {
            TextField("Name", text: flavour.name)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 150)
                .focused($focusedFlavour, equals: flavour.id)
                .onChange(of: flavour.wrappedValue.name) { highlighted = 0 }
                .onKeyPress(.downArrow) { moveHighlight(by: 1, in: flavour.wrappedValue) }
                .onKeyPress(.upArrow) { moveHighlight(by: -1, in: flavour.wrappedValue) }
                .onKeyPress(.return) { applyHighlighted(to: flavour) }
                .onKeyPress(.escape) {
                    guard isSuggesting(flavour.wrappedValue) else { return .ignored }
                    focusedFlavour = nil
                    return .handled
                }

            TextField("%", value: flavour.percent, format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .onChange(of: flavour.wrappedValue.percent) { _, new in
                    let clamped = min(max(new, RecipeLimits.flavour.lowerBound),
                                      RecipeLimits.flavour.upperBound)
                    if clamped != new { flavour.wrappedValue.percent = clamped }
                }

            Stepper("Percentage", value: flavour.percent, in: RecipeLimits.flavour, step: 1)
                .labelsHidden()

            CarrierPicker(carrier: flavour.carrier)

            dosageHint(for: flavour)

            Button {
                input.flavours.removeAll { $0.id == flavour.id }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .disabled(input.flavours.count <= 1)
            .help("Remove Flavour")
            .accessibilityLabel("Remove Flavour")
        }
    }

    /// Recommended dosage for a flavour that is in the catalogue; tap to apply it.
    @ViewBuilder
    private func dosageHint(for flavour: Binding<Flavour>) -> some View {
        if let entry = FlavorCatalog.shared.entry(named: flavour.wrappedValue.name) {
            let recommended = entry.percent
            Button {
                flavour.wrappedValue.percent = recommended
            } label: {
                Text(verbatim: "≈\(format(recommended))%")
                    .font(.caption.monospacedDigit())
            }
            .buttonStyle(.borderless)
            .disabled(flavour.wrappedValue.percent == recommended)
            .help(hintHelp(entry))
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }

    private func suggestionList(for flavour: Binding<Flavour>) -> some View {
        let matches = FlavorCatalog.shared.matches(for: flavour.wrappedValue.name)
        return VStack(spacing: 0) {
            ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                Button {
                    apply(match, to: flavour)
                } label: {
                    HStack(spacing: 8) {
                        Text(match.displayName)
                            .lineLimit(1)
                        Spacer(minLength: 12)
                        Text(verbatim: "\(format(match.percent))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                    .background(index == highlighted ? Color.accentColor.opacity(0.18) : .clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
        .frame(maxWidth: 420, alignment: .leading)
        .padding(.leading, 2)
    }

    private func isSuggesting(_ flavour: Flavour) -> Bool {
        focusedFlavour == flavour.id && !FlavorCatalog.shared.matches(for: flavour.name).isEmpty
    }

    private func moveHighlight(by offset: Int, in flavour: Flavour) -> KeyPress.Result {
        let matches = FlavorCatalog.shared.matches(for: flavour.name)
        guard focusedFlavour == flavour.id, !matches.isEmpty else { return .ignored }
        highlighted = (highlighted + offset + matches.count) % matches.count
        return .handled
    }

    private func applyHighlighted(to flavour: Binding<Flavour>) -> KeyPress.Result {
        let matches = FlavorCatalog.shared.matches(for: flavour.wrappedValue.name)
        guard isSuggesting(flavour.wrappedValue), matches.indices.contains(highlighted) else { return .ignored }
        apply(matches[highlighted], to: flavour)
        return .handled
    }

    private func apply(_ match: FlavorSuggestion, to flavour: Binding<Flavour>) {
        flavour.wrappedValue.name = match.displayName
        flavour.wrappedValue.percent = match.percent
        focusedFlavour = nil
        highlighted = 0
    }

    private func hintHelp(_ entry: FlavorSuggestion) -> String {
        let text = String(localized: "Typical dosage across \(entry.recipeCount) recipes")
        guard let range = entry.range else { return text }
        let low = format(range.lowerBound), high = format(range.upperBound)
        return String(localized: "\(text), range \(low)–\(high)%")
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

private struct Block<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        } label: {
            Text(title).font(.headline)
        }
    }
}
