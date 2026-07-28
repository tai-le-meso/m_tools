import SwiftUI
import Foundation

/// Input is optional: a number sets the output length (default 32, capped at 4096).
enum RandomStringLogic: DevToolLogic {
    private static let charset = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

    static func run(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let requested = Int(trimmed) ?? 32
        let length = max(1, min(requested, 4096))
        return String((0..<length).map { _ in charset.randomElement()! })
    }
}

struct RandomStringView: View {
    var body: some View {
        ToolView(title: "Random String Generator", transform: RandomStringLogic.run)
    }
}
