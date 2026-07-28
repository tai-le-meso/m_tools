import SwiftUI
import Foundation

/// Input is optional: a number sets the paragraph count (default 3, capped at 50); empty
/// or non-numeric input just uses the default. The first paragraph always opens with the
/// classic "Lorem ipsum dolor sit amet..." for authenticity.
enum LoremIpsumLogic: DevToolLogic {
    private static let bank = [
        "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit", "sed", "do",
        "eiusmod", "tempor", "incididunt", "ut", "labore", "et", "dolore", "magna", "aliqua", "enim",
        "ad", "minim", "veniam", "quis", "nostrud", "exercitation", "ullamco", "laboris", "nisi",
        "aliquip", "ex", "ea", "commodo", "consequat", "duis", "aute", "irure", "in", "reprehenderit",
        "voluptate", "velit", "esse", "cillum", "fugiat", "nulla", "pariatur", "excepteur", "sint",
        "occaecat", "cupidatat", "non", "proident", "sunt", "culpa", "qui", "officia", "deserunt",
        "mollit", "anim", "id", "est", "laborum",
    ]

    static func run(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let requested = Int(trimmed) ?? 3
        let paragraphCount = max(1, min(requested, 50))

        var paragraphs: [String] = []
        for index in 0..<paragraphCount {
            let isFirst = index == 0
            var words: [String] = isFirst
                ? ["Lorem", "ipsum", "dolor", "sit", "amet,", "consectetur", "adipiscing", "elit."]
                : []
            var remaining = Int.random(in: 40...70) - words.count
            while remaining > 0 {
                words.append(bank.randomElement()!)
                remaining -= 1
            }
            var sentence = words.joined(separator: " ")
            if !isFirst {
                sentence = sentence.prefix(1).uppercased() + sentence.dropFirst()
            }
            if !sentence.hasSuffix(".") { sentence += "." }
            paragraphs.append(sentence)
        }
        return paragraphs.joined(separator: "\n\n")
    }
}

struct LoremIpsumView: View {
    var body: some View {
        ToolView(title: "Lorem Ipsum Generator", transform: LoremIpsumLogic.run)
    }
}
