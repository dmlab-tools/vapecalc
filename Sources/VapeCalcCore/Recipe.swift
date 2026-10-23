import Foundation

public enum Carrier: String, CaseIterable, Sendable, Codable {
    case pg = "PG"
    case vg = "VG"

    /// g/ml at 20 °C. Nicotine bases and flavour concentrates are weighed as their carrier.
    public var density: Double {
        switch self {
        case .pg: 1.036
        case .vg: 1.261
        }
    }

    var densityDecimal: Decimal {
        switch self {
        case .pg: Decimal(1036) / 1000
        case .vg: Decimal(1261) / 1000
        }
    }
}

public struct Flavour: Identifiable, Sendable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var percent: Double
    public var carrier: Carrier

    public init(id: UUID = UUID(), name: String, percent: Double = 5, carrier: Carrier = .pg) {
        self.id = id
        self.name = name
        self.percent = percent
        self.carrier = carrier
    }
}

public struct RecipeInput: Sendable, Equatable, Codable {
    public var pgPercent: Double
    public var volumeMl: Double
    public var nicBaseStrength: Double
    public var nicBaseCarrier: Carrier
    public var nicotineMgMl: Double
    public var flavours: [Flavour]

    public init(
        pgPercent: Double = 50,
        volumeMl: Double = 30,
        nicBaseStrength: Double = 100,
        nicBaseCarrier: Carrier = .pg,
        nicotineMgMl: Double = 3,
        flavours: [Flavour] = [Flavour(name: String(localized: "Flavour \(1)"))]
    ) {
        self.pgPercent = pgPercent
        self.volumeMl = volumeMl
        self.nicBaseStrength = nicBaseStrength
        self.nicBaseCarrier = nicBaseCarrier
        self.nicotineMgMl = nicotineMgMl
        self.flavours = flavours
    }
}

public struct RecipeRow: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let name: String
    public let ml: Double
    public let grams: Double
    public let percent: Double

    public var isNegative: Bool { ml < 0 }
}

public struct RecipeResult: Sendable, Equatable {
    public let rows: [RecipeRow]
    public let totalMl: Double
    public let totalGrams: Double
    /// False when PG or VG goes negative: the mix does not fit the chosen ratio.
    public let isValid: Bool
}

/// Limits mirror the input constraints of the elsmoke.com.ua calculator.
public enum RecipeLimits {
    public static let volume: ClosedRange<Double> = 0...5000
    public static let nicBaseStrength: ClosedRange<Double> = 0...1000
    public static let nicotine: ClosedRange<Double> = 0...100
    public static let flavour: ClosedRange<Double> = 0...30
    public static let nicBasePresets: [Double] = [100, 150, 200, 500]
}

public enum RecipeCalculator {
    public static func calculate(_ input: RecipeInput) -> RecipeResult {
        let total = input.volumeMl.rounded(.towardZero)
        let pgPercent = input.pgPercent.rounded(.towardZero)
        let vgPercent = 100 - pgPercent
        let baseStrength = input.nicBaseStrength.rounded(.towardZero)
        let nicotine = round(input.nicotineMgMl, 1)

        var pgMl = total * pgPercent / 100
        var vgMl = total * vgPercent / 100

        var nicMl: Double = 0
        if baseStrength > 0 && nicotine > 0 {
            nicMl = round(total * ((nicotine * 100 / baseStrength) / 100), 2)
            switch input.nicBaseCarrier {
            case .pg: pgMl -= nicMl
            case .vg: vgMl -= nicMl
            }
        }

        var flavourRows: [RecipeRow] = []
        for flavour in input.flavours {
            let percent = round(flavour.percent, 2)
            var flavourMl: Double = 0
            if percent > 0 {
                flavourMl = round(percent * total / 100, 2)
                switch flavour.carrier {
                case .pg: pgMl -= flavourMl
                case .vg: vgMl -= flavourMl
                }
            }
            flavourRows.append(row(flavour.name, ml: flavourMl, carrier: flavour.carrier, total: total))
        }

        var rows = [
            row(String(localized: "PG (propylene glycol)"), ml: round(pgMl, 2), carrier: .pg, total: total),
            row(String(localized: "VG (glycerin)"), ml: round(vgMl, 2), carrier: .vg, total: total),
            row(String(localized: "Nicotine base"), ml: nicMl, carrier: input.nicBaseCarrier, total: total),
        ]
        rows.append(contentsOf: flavourRows)

        return RecipeResult(
            rows: rows,
            totalMl: total,
            totalGrams: (rows.reduce(0) { $0 + $1.grams } * 100).rounded() / 100,
            isValid: round(pgMl, 2) >= 0 && round(vgMl, 2) >= 0
        )
    }

    private static func row(_ name: String, ml: Double, carrier: Carrier, total: Double) -> RecipeRow {
        RecipeRow(
            name: name,
            ml: ml,
            grams: grams(ml: ml, carrier: carrier),
            percent: total == 0 ? 0 : round(ml / total * 100, 2)
        )
    }

    /// Decimal maths keeps the weight exact: `15 * 1.261` is 18.915 g and rounds to 18.92,
    /// which binary doubles get wrong by a hundredth.
    private static func grams(ml: Double, carrier: Carrier) -> Double {
        guard ml.isFinite else { return 0 }
        var product = Decimal(Int64((ml * 100).rounded())) / 100 * carrier.densityDecimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &product, 2, .plain)
        return Double(rounded.description) ?? 0
    }

    /// Mirrors JavaScript's `toFixed`: rounds the exact binary value of the double,
    /// half away from zero. The site's numbers depend on both details.
    private static func round(_ value: Double, _ places: Int) -> Double {
        guard value.isFinite else { return 0 }
        let negative = value < 0
        let text = String(format: "%.\(places + 25)f", abs(value))
        guard let dot = text.firstIndex(of: ".") else { return value }
        let digits = text[text.startIndex..<dot] + text[text.index(after: dot)...].prefix(places)
        let tail = text[text.index(after: dot)...].dropFirst(places)
        guard var scaled = Int64(digits) else { return value }

        if let next = tail.first, next >= "5" {
            scaled += 1
        }

        let result = Double(scaled) / pow(10, Double(places))
        return negative ? -result : result
    }
}
