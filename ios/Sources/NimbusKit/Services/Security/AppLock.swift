import Foundation

/// Biometric capability of the device.
public enum BiometricType: String, Sendable {
    case none, touchID, faceID, opticID

    public var displayName: String {
        switch self {
        case .none: return "Passcode"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        }
    }
}

/// Biometric / passcode authentication. The app injects a
/// `LocalAuthentication`-backed implementation; the core provides a stub so the
/// App Lock and "Face ID to unlock configs" flows are wired end-to-end and
/// testable.
public protocol AppLockAuthenticating: Sendable {
    var biometryType: BiometricType { get }
    /// Prompt the user; returns `true` on success.
    func authenticate(reason: String) async -> Bool
}

/// Always-succeeds stub used off-device / in tests.
public struct AlwaysAllowAppLock: AppLockAuthenticating {
    public let biometryType: BiometricType
    public init(biometryType: BiometricType = .faceID) { self.biometryType = biometryType }
    public func authenticate(reason: String) async -> Bool { true }
}

/// Coordinates the App-Lock state machine: whether the library is currently
/// locked, and unlocking it via ``AppLockAuthenticating``.
public actor AppLockController {
    public private(set) var isLocked: Bool
    private let authenticator: AppLockAuthenticating
    /// Whether App Lock is enabled at all (Settings → Security).
    public var isEnabled: Bool

    public init(authenticator: AppLockAuthenticating, enabled: Bool = false) {
        self.authenticator = authenticator
        self.isEnabled = enabled
        self.isLocked = enabled
    }

    public var biometryType: BiometricType { authenticator.biometryType }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled { isLocked = false }
    }

    /// Call when the app returns to the foreground.
    public func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    @discardableResult
    public func unlock(reason: String = "Unlock your Nimbus library") async -> Bool {
        guard isLocked else { return true }
        let ok = await authenticator.authenticate(reason: reason)
        if ok { isLocked = false }
        return ok
    }
}
