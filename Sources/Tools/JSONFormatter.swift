import SwiftUI
import Foundation

enum JSONFormatterLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        guard let data = input.data(using: .utf8) else {
            throw DevToolError.invalidInput("Input isn't valid UTF-8 text.")
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let pretty = try JSONSerialization.data(
                withJSONObject: obj,
                options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
            )
            return String(data: pretty, encoding: .utf8) ?? ""
        } catch {
            throw DevToolError.invalidInput("Invalid JSON: \(error.localizedDescription)")
        }
    }
}

struct JSONFormatterView: View {
    var body: some View {
        ToolView(title: "JSON Formatter", language: .json, transform: JSONFormatterLogic.run)
    }
}
