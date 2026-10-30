import Foundation
// StikJIT.xcframework must be vendored into ./Vendor and embedded in this
// target — see the root README's Building section. Its documented entry
// point is:
//
//   StikJIT.enableJIT(targetPID:pairingFile:configuration:script:progress:)
//
// which is synchronous/blocking and throws `StikJITError`
// (see https://github.com/StikDebug/StikJIT, Integration Guide).
import StikJIT

/// `NSExtensionPrincipalClass` for the `PocketJITHelper` app extension.
/// Runs in its own process so `StikJIT.enableJIT` doesn't have to share a
/// process with the host app's UI, matching StikJIT's documented
/// integration pattern.
final class HelperExtension: NSObject, NSExtensionRequestHandling {
    private var listener: NSXPCListener?

    func beginRequest(with context: NSExtensionContext) {
        // The extension is activated once by the host app launching it;
        // from then on all real work comes in over the XPC listener below,
        // not through the extension-request item itself.
        startListenerIfNeeded()
        context.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func startListenerIfNeeded() {
        guard listener == nil else { return }
        let listener = NSXPCListener(machServiceName: JITXPC.serviceName)
        listener.delegate = self
        listener.resume()
        self.listener = listener
    }
}

extension HelperExtension: NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: JITHelperProtocol.self)
        newConnection.exportedObject = JITHelperService()
        newConnection.resume()
        return true
    }
}

/// The object that actually answers XPC calls from the host app.
final class JITHelperService: NSObject, JITHelperProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    func enableJIT(
        targetPID: pid_t,
        pairingFileData: Data,
        withReply reply: @escaping (String?) -> Void
    ) {
        // enableJIT is blocking, so hop off whatever queue XPC delivered
        // this call on before calling it.
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let pairingURL = try Self.writeTemporaryPairingFile(pairingFileData)
                defer { try? FileManager.default.removeItem(at: pairingURL) }

                try StikJIT.enableJIT(
                    targetPID: targetPID,
                    pairingFile: pairingURL,
                    progress: { _ in /* surface via a progress XPC callback if desired */ }
                )
                reply(nil)
            } catch {
                reply(String(describing: error))
            }
        }
    }

    private static func writeTemporaryPairingFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("plist")
        try data.write(to: url, options: .atomic)
        return url
    }
}
