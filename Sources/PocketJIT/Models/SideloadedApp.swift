import Foundation

/// A sideloaded, `get-task-allow`-signed app that JIT can be enabled for.
///
/// Populated today by manual entry (see `InstalledAppsProvider`); the TODO
/// in the README is to fill this list automatically via `installation_proxy`
/// over the same device tunnel `idevice` already opens for pairing.
struct SideloadedApp: Identifiable, Hashable, Codable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let displayName: String
    /// PID while running; `nil` means "not currently launched" — JIT can
    /// only be enabled for a process that's already alive.
    var pid: pid_t?
}
