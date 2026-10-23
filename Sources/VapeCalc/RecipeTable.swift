import SwiftUI
import VapeCalcCore

struct RecipeTable: View {
    let result: RecipeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Recipe")
                .font(.title3.bold())

            if !result.isValid {
                Label(
                    "This recipe does not fit the current PG / VG ratio. Change the ratio or lower the dosages.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.callout)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                GridRow {
                    Text("Component").gridColumnAlignment(.leading)
                    Text("ml").gridColumnAlignment(.trailing)
                    Text("g").gridColumnAlignment(.trailing)
                    Text(verbatim: "%").gridColumnAlignment(.trailing)
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)

                Divider().gridCellUnsizedAxes(.horizontal)

                ForEach(result.rows) { row in
                    GridRow {
                        Text(row.name).lineLimit(1)
                        Text(ml(row.ml))
                        Text(number(row.grams))
                        Text(percent(row.percent))
                    }
                    .foregroundStyle(row.isNegative ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                }

                Divider().gridCellUnsizedAxes(.horizontal)

                GridRow {
                    Text("Total")
                    Text(ml(result.totalMl))
                    Text(number(result.totalGrams))
                    Text(verbatim: "100%")
                }
                .font(.body.bold())
            }
            .monospacedDigit()

            Text("Weight uses the carrier density: PG 1.036 g/ml, VG 1.261 g/ml.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func ml(_ value: Double) -> String {
        String(localized: "\(number(value)) ml")
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2))) + "%"
    }
}
