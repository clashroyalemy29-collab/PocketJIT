import Foundation

/// Source of the apps shown in the picker.
///
/// A sandboxed iOS app has no public API to list *other* apps' bundle ids
/// or PIDs — StikDebug-style tools instead ask the device itself, over the
/// same pairing tunnel, via the `installation_proxy` lockdown service
/// (for bundle ids) and `debugserver`'s process list (for live PIDs).
/// Wiring that up is the TODO noted in the README; until then this is a
/// small, explicit, user-maintained list so the rest of the app (XPC call,
/// JIT trigger, progress UI) is fully functional end to end.
@MainActor
final class InstalledAppsProvider: ObservableObject {
    @Published var apps: [SideloadedApp] = []

    private let storageURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("pocketjit-apps.json")
    }()

    init() {
        load()
    }

    func add(bundleIdentifier: String, displayName: String) {
        guard !bundleIdentifier.isEmpty else { return }
        let app = SideloadedApp(bundleIdentifier: bundleIdentifier, displayName: displayName, pid: nil)
        apps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        apps.append(app)
        save()
    }

    func remove(_ app: SideloadedApp) {
        apps.removeAll { $0.id == app.id }
        save()
    }

    /// Manual PID entry until automatic process lookup (TODO above) exists:
    /// run the target app, check Settings → Developer Mode → (or a tool
    /// like StikDebug) for its PID, enter it here.
    func setPID(_ pid: pid_t?, for app: SideloadedApp) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].pid = pid
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([SideloadedApp].self, from: data)
        else { return }
        apps = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(apps) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
