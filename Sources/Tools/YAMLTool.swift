import SwiftUI
import Foundation

enum YAMLToJSONLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        do {
            let value = try YAMLParser.parse(input)
            let obj = YAMLParser.toJSONObject(value)
            let data = try JSONSerialization.data(
                withJSONObject: obj,
                options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
            )
            return String(data: data, encoding: .utf8) ?? ""
        } catch let error as YAMLError {
            throw DevToolError.invalidInput("Invalid YAML: \(error.errorDescription ?? "syntax error")")
        } catch {
            throw DevToolError.invalidInput("Couldn't convert to JSON: \(error.localizedDescription)")
        }
    }
}

enum JSONToYAMLLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        guard let data = input.data(using: .utf8) else {
            throw DevToolError.invalidInput("Input isn't valid UTF-8 text.")
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let value = YAMLParser.fromJSONObject(obj)
            return YAMLParser.serialize(value)
        } catch {
            throw DevToolError.invalidInput("Invalid JSON: \(error.localizedDescription)")
        }
    }
}

struct YAMLToJSONView: View {
    var body: some View {
        ToolView(title: "YAML → JSON", language: .json, transform: YAMLToJSONLogic.run)
    }
}

struct JSONToYAMLView: View {
    var body: some View {
        ToolView(title: "JSON → YAML", language: .yaml, transform: JSONToYAMLLogic.run)
    }
}
