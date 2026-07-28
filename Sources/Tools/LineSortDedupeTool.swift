import SwiftUI
import Foundation

/// Sorts lines alphabetically and drops exact duplicates (first occurrence order broken
/// by the sort, which is fine — the point is a clean, unique, ordered list).
enum LineSortDedupeLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.isEmpty else { return "" }
        let lines = input.components(separatedBy: "\n")
        var seen = Set<String>()
        var unique: [String] = []
        for line in lines where !seen.contains(line) {
            seen.insert(line)
            unique.append(line)
        }
        return unique.sorted().joined(separator: "\n")
    }
}

struct LineSortDedupeView: View {
    var body: some View {
        ToolView(title: "Line Sort/Dedupe", transform: LineSortDedupeLogic.run)
    }
}
