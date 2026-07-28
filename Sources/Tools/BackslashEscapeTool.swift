import SwiftUI
import Foundation

/// Auto-detects direction: input containing a backslash is treated as escaped and
/// unescaped; otherwise the common control characters are escaped.
enum BackslashEscapeLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.isEmpty else { return "" }
        return input.contains("\\") ? unescape(input) : escape(input)
    }

    private static func escape(_ s: String) -> String {
        var result = ""
        for ch in s {
            switch ch {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\t": result += "\\t"
            case "\r": result += "\\r"
            default: result.append(ch)
            }
        }
        return result
    }

    private static func unescape(_ s: String) -> String {
        var result = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            if chars[i] == "\\", i + 1 < chars.count {
                switch chars[i + 1] {
                case "n": result += "\n"; i += 2
                case "t": result += "\t"; i += 2
                case "r": result += "\r"; i += 2
                case "\\": result += "\\"; i += 2
                case "\"": result += "\""; i += 2
                default: result.append(chars[i]); i += 1
                }
            } else {
                result.append(chars[i]); i += 1
            }
        }
        return result
    }
}

struct BackslashEscapeView: View {
    var body: some View {
        ToolView(title: "Backslash Escape/Unescape", transform: BackslashEscapeLogic.run)
    }
}
