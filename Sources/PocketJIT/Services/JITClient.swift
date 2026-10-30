import Foundation

/// Host-app side of the XPC bridge to `PocketJITHelper`. The actual
/// `StikJIT.enableJIT` call lives in the extension process (see that
/// target's `HelperExtension.swift`); this class just manages the
/// connection and surfaces results as `async`.
@MainActor
final class JITClient: ObservableObject {
    @Published private(set) var isEnabling = false
    @Published private(set) var lastResult: String?

    private var connection: NSXPCConnection?

    private func makeConnection() -> NSXPCConnection {
        if let connection { return connection }
        let connection = NSXPCConnection(serviceName: JITXPC.serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: JITHelperProtocol.self)
        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        connection.resume()
        self.connection = connection
        return connection
    }

    func ping() async -> Bool {
        await withCheckedContinuation { continuation in
            let proxy = makeConnection().remoteObjectProxyWithErrorHandler { _ in
                continuation.resume(returning: false)
            } as? JITHelperProtocol
            proxy?.ping { ok in
                continuation.resume(returning: ok)
            }
        }
    }

    /// Enables JIT for `app`, which must already be running (`app.pid != nil`).
    func enableJIT(for app: SideloadedApp) async {
        guard let pid = app.pid else {
            lastResult = "\(app.displayName) isn't running — launch it first, then set its PID."
            return
        }
        guard let pairingData = PairingStore.currentPairingData() else {
            lastResult = "Not paired with this device yet."
            return
        }

        isEnabling = true
        defer { isEnabling = false }

        let errorDescription: String? = await withCheckedContinuation { continuation in
            let proxy = makeConnection().remoteObjectProxyWithErrorHandler { error in
                continuation.resume(returning: error.localizedDescription)
            } as? JITHelperProtocol
            proxy?.enableJIT(targetPID: pid, pairingFileData: pairingData) { error in
                continuation.resume(returning: error)
            }
        }

        lastResult = errorDescription.map { "Failed: \($0)" }
            ?? "JIT enabled for \(app.displayName) \u{2014} it's ready to use."
    }
}
