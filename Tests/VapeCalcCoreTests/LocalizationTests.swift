import Foundation
import Testing

// Checks the app's Resources/*.lproj tables; the Russian literals are the expected translations.

private let resources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("../../Resources")
    .standardizedFileURL

private func bundle(_ language: String) throws -> Bundle {
    try #require(Bundle(url: resources.appendingPathComponent("\(language).lproj")))
}

private func table(_ language: String) throws -> [String: String] {
    let url = resources.appendingPathComponent("\(language).lproj/Localizable.strings")
    let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
    return try #require(plist as? [String: String])
}

/// Format specifiers with positional indexes stripped, e.g. "%2$@" -> "%@".
private func specifiers(_ text: String) -> [String] {
    let regex = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(@|lld|%)"#)
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).map { "%" + (text as NSString).substring(with: $0.range(at: 1)) }
}

@Test func russianTranslationsKeepFormatSpecifiers() throws {
    let russian = try table("ru")
    #expect(russian.count > 50)
    for (key, value) in russian {
        #expect(specifiers(key).sorted() == specifiers(value).sorted(), "\(key)")
    }
}

@Test func russianStringsResolve() throws {
    let ru = try bundle("ru")
    #expect(ru.localizedString(forKey: "Save as Recipe", value: nil, table: nil) == "Сохранить как рецепт")
    #expect(ru.localizedString(forKey: "Variant…", value: nil, table: nil) == "Вариант…")
    let format = ru.localizedString(forKey: "%@ (%@ ml, %@ mg)", value: nil, table: nil)
    #expect(String(format: format, "Mango", "60", "6") == "Mango (60 мл, 6 мг)")
}

@Test(arguments: [(1, "рецепту"), (3, "рецептам"), (5, "рецептам"), (21, "рецепту"), (112, "рецептам")])
func russianRecipeCountIsPluralized(count: Int, word: String) throws {
    let format = try bundle("ru").localizedString(forKey: "Typical dosage across %lld recipes", value: nil, table: nil)
    let text = String(format: format, locale: Locale(identifier: "ru"), count)
    #expect(text == "Обычная дозировка по \(count) \(word)")
}

@Test func englishRecipeCountIsPluralized() throws {
    let format = try bundle("en").localizedString(forKey: "Typical dosage across %lld recipes", value: nil, table: nil)
    #expect(String(format: format, locale: Locale(identifier: "en"), 1) == "Typical dosage across 1 recipe")
    #expect(String(format: format, locale: Locale(identifier: "en"), 7) == "Typical dosage across 7 recipes")
}
