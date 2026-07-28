import SwiftUI
import Foundation

/// Custom PHP `serialize()`/`unserialize()` codec — no third-party package needed. JSON is
/// used as the interchange representation on the Swift side (strings/numbers/bools/null/
/// arrays/objects), which covers everything PHP's serialize format itself supports outside
/// of PHP-specific object instances.
enum PHPSerializeLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        guard let data = input.data(using: .utf8) else {
            throw DevToolError.invalidInput("Input isn't valid UTF-8 text.")
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return serialize(obj)
        } catch {
            throw DevToolError.invalidInput("Invalid JSON: \(error.localizedDescription)")
        }
    }

    private static func serialize(_ value: Any) -> String {
        switch value {
        case let s as String:
            return "s:\(s.utf8.count):\"\(s)\";"
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return "b:\(n.boolValue ? 1 : 0);"
            }
            if n.doubleValue == n.doubleValue.rounded(.towardZero), abs(n.doubleValue) < 1e18 {
                return "i:\(n.int64Value);"
            }
            return "d:\(n.doubleValue);"
        case is NSNull:
            return "N;"
        case let arr as [Any]:
            let items = arr.enumerated().map { index, item in "i:\(index);" + serialize(item) }.joined()
            return "a:\(arr.count):{\(items)}"
        case let dict as [String: Any]:
            let keys = dict.keys.sorted()
            let items = keys.map { key in serialize(key) + serialize(dict[key]!) }.joined()
            return "a:\(dict.count):{\(items)}"
        default:
            return "N;"
        }
    }
}

enum PHPUnserializeLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let chars = Array(trimmed)
        var i = 0
        let value = try parseValue(chars, &i)
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func parseValue(_ chars: [Character], _ i: inout Int) throws -> Any {
        guard i < chars.count else { throw DevToolError.invalidInput("Unexpected end of input.") }
        switch chars[i] {
        case "N":
            i += 2 // "N;"
            return NSNull()
        case "b":
            i += 2 // "b:"
            guard i < chars.count else { throw DevToolError.invalidInput("Malformed bool.") }
            let val = chars[i] == "1"
            i += 2 // digit + ";"
            return val
        case "i":
            i += 2 // "i:"
            let (numStr, next) = readUntil(chars, i, ";")
            i = next + 1
            guard let n = Int(numStr) else { throw DevToolError.invalidInput("Malformed integer: \(numStr)") }
            return n
        case "d":
            i += 2 // "d:"
            let (numStr, next) = readUntil(chars, i, ";")
            i = next + 1
            guard let d = Double(numStr) else { throw DevToolError.invalidInput("Malformed double: \(numStr)") }
            return d
        case "s":
            i += 2 // "s:"
            let (lenStr, colonIdx) = readUntil(chars, i, ":")
            guard let byteLen = Int(lenStr) else { throw DevToolError.invalidInput("Malformed string length.") }
            i = colonIdx + 1
            guard i < chars.count, chars[i] == "\"" else { throw DevToolError.invalidInput("Expected opening quote in string.") }
            i += 1
            guard let remainingData = String(chars[i...]).data(using: .utf8) else {
                throw DevToolError.invalidInput("Bad text encoding.")
            }
            let strBytes = remainingData.prefix(byteLen)
            guard let str = String(data: strBytes, encoding: .utf8) else {
                throw DevToolError.invalidInput("Malformed string content (bad byte length).")
            }
            i += str.count
            guard i < chars.count, chars[i] == "\"" else { throw DevToolError.invalidInput("Expected closing quote in string.") }
            i += 1
            if i < chars.count, chars[i] == ";" { i += 1 }
            return str
        case "a":
            i += 2 // "a:"
            let (countStr, colonIdx) = readUntil(chars, i, ":")
            guard let count = Int(countStr) else { throw DevToolError.invalidInput("Malformed array count.") }
            i = colonIdx + 1
            guard i < chars.count, chars[i] == "{" else { throw DevToolError.invalidInput("Expected '{' to start array.") }
            i += 1

            var isList = true
            var expectedIndex = 0
            var dict: [String: Any] = [:]
            var list: [Any] = []
            for _ in 0..<count {
                let key = try parseValue(chars, &i)
                let val = try parseValue(chars, &i)
                if let intKey = key as? Int, intKey == expectedIndex {
                    list.append(val)
                    expectedIndex += 1
                } else {
                    isList = false
                }
                dict["\(key)"] = val
            }
            guard i < chars.count, chars[i] == "}" else { throw DevToolError.invalidInput("Expected '}' to close array.") }
            i += 1
            return isList ? list : dict
        default:
            throw DevToolError.invalidInput("Unrecognized PHP serialized type marker: \(chars[i])")
        }
    }

    /// Reads characters from `start` up to (not including) the next occurrence of
    /// `terminator`, returning the text and the terminator's index.
    private static func readUntil(_ chars: [Character], _ start: Int, _ terminator: Character) -> (String, Int) {
        var j = start
        while j < chars.count, chars[j] != terminator { j += 1 }
        return (String(chars[start..<j]), j)
    }
}

struct PHPSerializeToolView: View {
    var body: some View {
        ToolView(title: "PHP Serialize/Unserialize", modes: [
            .init("JSON → PHP", PHPSerializeLogic.run),
            .init("PHP → JSON", PHPUnserializeLogic.run),
        ])
    }
}
