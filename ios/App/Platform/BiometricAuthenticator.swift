import Foundation
import NimbusKit
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// Production ``AppLockAuthenticating`` backed by `LocalAuthentication` (Face ID /
/// Touch ID / Optic ID, falling back to device passcode).
struct BiometricAuthenticator: AppLockAuthenticating {
    var biometryType: BiometricType {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default:
            if #available(iOS 17.0, *), context.biometryType == .opticID { return .opticID }
            return .none
        }
        #else
        return .none
        #endif
    }

    func authenticate(reason: String) async -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
        #else
        return true
        #endif
    }
}
