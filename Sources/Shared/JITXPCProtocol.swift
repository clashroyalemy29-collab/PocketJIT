import Foundation

/// Spoken over `NSXPCConnection` between `PocketJIT` (the host app) and
/// `PocketJITHelper` (the extension that actually links `StikJIT`).
///
/// The split exists because `StikJIT.enableJIT` is documented as needing to
/// run in its own process — see StikJIT's integration guide, "JIT
/// Enablement Flow".
@objc public protocol JITHelperProtocol {
    /// Attach a debugger to `targetPID` and enable JIT for it, then detach.
    ///
    /// - Parameters:
    ///   - targetPID: PID of the already-launched sideloaded app.
    ///   - pairingFileData: contents of the on-device pairing file
    ///     (`PairingStore.currentPairingData()` on the host side).
    ///   - reply: called once, on an arbitrary queue, with `nil` on success
    ///     or a human-readable error description on failure.
    func enableJIT(
        targetPID: pid_t,
        pairingFileData: Data,
        withReply reply: @escaping (String?) -> Void
    )

    /// Lightweight ping so the host app can show "Helper ready" vs
    /// "Helper not responding" in the UI before the user taps Enable JIT.
    func ping(withReply reply: @escaping (Bool) -> Void)
}

/// Mach service name the extension's XPC listener advertises and the host
/// app connects to. Must match `NSExtensionPrincipalClass`'s listener setup
/// in `HelperExtension.swift` and the extension's bundle identifier suffix.
public enum JITXPC {
    public static let serviceName = "com.pocketjit.app.helper"
}
