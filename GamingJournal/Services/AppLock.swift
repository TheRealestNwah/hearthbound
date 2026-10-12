import Foundation
import LocalAuthentication
import Observation

/// Face ID, Touch ID or passcode, so tests can stand in for the device.
protocol Authenticating {
    /// "Face ID", "Touch ID", "Passcode" or, on Mac, "Password": what unlocking will ask for.
    var method: String { get }
    func authenticate(reason: String) async -> Bool
}

struct DeviceAuthenticator: Authenticating {
    var method: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default:
            #if os(macOS)
            return "Password"
            #else
            return "Passcode"
            #endif
        }
    }

    func authenticate(reason: String) async -> Bool {
        // Falls back to the device passcode when biometrics aren't set up or fail.
        (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// An optional lock on the whole journal. When on, the app opens sealed and seals itself again
/// whenever it goes to the background (on Mac: is hidden, minimised, closed or the screen locks).
@Observable
final class AppLock {
    static let enabledKey = "lock.enabled"

    private(set) var isLocked: Bool
    private(set) var isEnabled: Bool
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let authenticator: Authenticating
    /// One prompt at a time: appearing and becoming active can both ask to unlock.
    @ObservationIgnored private var isAuthenticating = false

    init(defaults: UserDefaults = .standard, authenticator: Authenticating = DeviceAuthenticator()) {
        self.defaults = defaults
        self.authenticator = authenticator
        let enabled = defaults.bool(forKey: Self.enabledKey)
        isEnabled = enabled
        isLocked = enabled
    }

    var method: String { authenticator.method }

    /// Whether the lock is on, for code without an instance (widget snapshot, Spotlight).
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await authenticator.authenticate(reason: "Open your journal") {
            isLocked = false
        }
    }

    /// The app left the foreground.
    func seal() {
        if isEnabled { isLocked = true }
    }

    /// Turning the lock on or off both need the owner to authenticate, so someone holding an
    /// unlocked phone can't quietly change it. Returns whether the change went through.
    @discardableResult
    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled != isEnabled else { return true }
        let reason = enabled ? "Lock your journal" : "Stop locking your journal"
        guard await authenticator.authenticate(reason: reason) else { return false }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        return true
    }
}
