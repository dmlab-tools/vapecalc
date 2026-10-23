import SwiftUI
import VapeCalcCore

/// Text field with a stepper, clamped to `range` like the web calculator's number inputs.
struct NumberField: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var help: LocalizedStringKey?

    private var format: FloatingPointFormatStyle<Double> {
        .number.precision(.fractionLength(0...2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField(title, value: $value, format: format)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(minWidth: 70)
                    .onChange(of: value) { _, new in
                        let clamped = min(max(new, range.lowerBound), range.upperBound)
                        if clamped != new { value = clamped }
                    }
                Stepper(title, value: $value, in: range, step: step)
                    .labelsHidden()
            }
        }
        .help(help.map { Text($0) } ?? Text(verbatim: ""))
    }
}

struct CarrierPicker: View {
    @Binding var carrier: Carrier

    var body: some View {
        Picker("Carrier", selection: $carrier) {
            ForEach(Carrier.allCases, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 96)
    }
}
