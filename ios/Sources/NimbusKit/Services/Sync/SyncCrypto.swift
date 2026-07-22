import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// End-to-end encryption for synchronized configuration data. Sync payloads are
/// encrypted on-device with a key derived from the user's passphrase, so the
/// cloud only ever stores ciphertext.
public protocol ConfigurationCipher: Sendable {
    /// Encrypt `plaintext` using `passphrase`. Output is self-describing
    /// (contains salt + nonce) so `decrypt` needs only the passphrase.
    func encrypt(_ plaintext: Data, passphrase: String) throws -> Data
    func decrypt(_ ciphertext: Data, passphrase: String) throws -> Data
    /// Whether this cipher provides real confidentiality.
    var isEncrypting: Bool { get }
}

/// No-op cipher used when E2E encryption is disabled or on platforms without
/// CryptoKit (keeps the core buildable/testable on Linux). It is *not*
/// confidential — the app must only select it when the user opts out of E2E.
public struct PassthroughCipher: ConfigurationCipher {
    public init() {}
    public var isEncrypting: Bool { false }
    public func encrypt(_ plaintext: Data, passphrase: String) throws -> Data { plaintext }
    public func decrypt(_ ciphertext: Data, passphrase: String) throws -> Data { ciphertext }
}

#if canImport(CryptoKit)
/// AES-GCM E2E cipher. The key is derived from the passphrase with HKDF-SHA256
/// over a random 16-byte salt; output layout is `salt(16) ‖ AES-GCM.combined`.
public struct AESGCMCipher: ConfigurationCipher {
    public init() {}
    public var isEncrypting: Bool { true }

    private func deriveKey(passphrase: String, salt: Data) -> SymmetricKey {
        let secret = SymmetricKey(data: Data(passphrase.utf8))
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: secret,
            salt: salt,
            info: Data("nimbus.e2e.v1".utf8),
            outputByteCount: 32
        )
        return derived
    }

    public func encrypt(_ plaintext: Data, passphrase: String) throws -> Data {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomFallback.fill($0) }
        let key = deriveKey(passphrase: passphrase, salt: salt)
        do {
            let sealed = try AES.GCM.seal(plaintext, using: key)
            guard let combined = sealed.combined else {
                throw NimbusError.crypto(reason: "failed to combine sealed box")
            }
            return salt + combined
        } catch {
            throw NimbusError.crypto(reason: "encrypt failed: \(error)")
        }
    }

    public func decrypt(_ ciphertext: Data, passphrase: String) throws -> Data {
        guard ciphertext.count > 16 else { throw NimbusError.crypto(reason: "ciphertext too short") }
        let salt = ciphertext.prefix(16)
        let body = ciphertext.suffix(from: ciphertext.startIndex + 16)
        let key = deriveKey(passphrase: passphrase, salt: Data(salt))
        do {
            let box = try AES.GCM.SealedBox(combined: body)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw NimbusError.crypto(reason: "decrypt failed — wrong passphrase or corrupt data")
        }
    }
}

/// Small shim so the file compiles even where `SecRandomCopyBytes` isn't
/// imported; CryptoKit platforms always have Security.
private enum SecRandomFallback {
    static func fill(_ buffer: UnsafeMutableRawBufferPointer) -> Int32 {
        for i in 0..<buffer.count { buffer[i] = UInt8.random(in: 0...255) }
        return 0
    }
}
#endif
