import SwiftUI
import Foundation

/// Splits input into words (on non-alphanumeric boundaries and camelCase humps), then
/// renders every common case style from that shared word list.
enum StringCaseConverterLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let words = tokenize(input)
        guard !words.isEmpty else {
            throw DevToolError.invalidInput("No word characters found.")
        }

        return """
        camelCase:   \(camelCase(words))
        PascalCase:  \(pascalCase(words))
        snake_case:  \(words.map { $0.lowercased() }.joined(separator: "_"))
        kebab-case:  \(words.map { $0.lowercased() }.joined(separator: "-"))
        CONST_CASE:  \(words.map { $0.uppercased() }.joined(separator: "_"))
        Title Case:  \(words.map { $0.capitalized }.joined(separator: " "))
        """
    }

    private static func tokenize(_ s: String) -> [String] {
        var words: [String] = []
        var current = ""
        var prevWasLower = false
        for ch in s {
            if ch.isLetter || ch.isNumber {
                if ch.isUppercase, prevWasLower, !current.isEmpty {
                    words.append(current)
                    current = ""
                }
                current.append(ch)
                prevWasLower = ch.isLowercase
            } else {
                if !current.isEmpty { words.append(current) }
                current = ""
                prevWasLower = false
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    private static func camelCase(_ words: [String]) -> String {
        guard let first = words.first else { return "" }
        let rest = words.dropFirst().map { capitalize($0) }.joined()
        return first.lowercased() + rest
    }

    private static func pascalCase(_ words: [String]) -> String {
        words.map { capitalize($0) }.joined()
    }

    private static func capitalize(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst().lowercased()
    }
}

struct StringCaseConverterView: View {
    var body: some View {
        ToolView(title: "String Case Converter", transform: StringCaseConverterLogic.run)
    }
}
