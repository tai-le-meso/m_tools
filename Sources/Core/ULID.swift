import Foundation

// Custom ULID (Universally Unique Lexicographically sortable IDentifier) encode/decode —
// no third-party package needed. Format: 48-bit millisecond timestamp + 80-bit randomness,
// both encoded in Crockford's Base32 (26 characters total). Spec: https://github.com/ulid/spec

enum ULID {
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func generate() -> String {
        let millis = UInt64(Date().timeIntervalSince1970 * 1000)
        return encodeTime(millis) + encodeRandom()
    }

    private static func encodeTime(_ millis: UInt64) -> String {
        var chars = [Character](repeating: "0", count: 10)
        var value = millis
        for i in stride(from: 9, through: 0, by: -1) {
            chars[i] = alphabet[Int(value % 32)]
            value /= 32
        }
        return String(chars)
    }

    private static func encodeRandom() -> String {
        String((0..<16).map { _ in alphabet[Int.random(in: 0..<32)] })
    }

    /// Decodes the leading 10 characters (the timestamp part) of a ULID.
    static func timestamp(from ulid: String) -> Date? {
        guard ulid.count == 26 else { return nil }
        let upper = ulid.uppercased()
        var value: UInt64 = 0
        for c in upper.prefix(10) {
            guard let idx = alphabet.firstIndex(of: c) else { return nil }
            value = value * 32 + UInt64(idx)
        }
        return Date(timeIntervalSince1970: Double(value) / 1000)
    }

    static func isValid(_ s: String) -> Bool {
        guard s.count == 26 else { return false }
        let upper = Set(s.uppercased())
        return upper.isSubset(of: Set(alphabet))
    }
}
