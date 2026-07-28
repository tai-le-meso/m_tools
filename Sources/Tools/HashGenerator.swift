import SwiftUI
import Foundation
import CryptoKit

enum HashGeneratorLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard let data = input.data(using: .utf8), !data.isEmpty else { return "" }

        // CryptoKit's `Insecure` namespace is Apple's own non-deprecated replacement for
        // CommonCrypto's CC_MD5/CC_SHA1 — it exists specifically so legacy/compatibility
        // hashing (checksums, cache keys, etc. — not security) doesn't need a deprecated C
        // API. SHA-256 has no "Insecure" variant since it's still fine as-is. Digest bytes
        // are identical to CommonCrypto's for the same input — this only changes how we
        // call into the algorithm, not the algorithm itself.
        let md5 = Insecure.MD5.hash(data: data)
        let sha1 = Insecure.SHA1.hash(data: data)
        let sha256 = SHA256.hash(data: data)

        return """
        MD5:     \(hex(md5))
        SHA-1:   \(hex(sha1))
        SHA-256: \(hex(sha256))
        """
        // Keccak-256 intentionally omitted here — not in CryptoKit/CommonCrypto, needs a
        // small hand-written implementation (Keccak-f[1600] permutation). See task-plan.md.
    }

    private static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct HashGeneratorView: View {
    var body: some View {
        ToolView(title: "Hash Generator", transform: HashGeneratorLogic.run)
    }
}
