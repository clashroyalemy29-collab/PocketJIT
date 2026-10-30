import Foundation
import UniformTypeIdentifiers

/// Drives the one-time "make this phone trust this app as a debugger"
/// handshake, then hands the resulting pairing record to `PairingStore`.
///
/// Two paths, matching what's publicly documented for the two OS versions:
///
/// - **iOS 27**: Settings ships its own `Pair with…` screen (Settings →
///   Privacy & Security → Developer Mode). The app side of that handshake
///   is the still-undocumented "RPPairing" protocol that `idevice` itself
///   calls "a mystery as of writing" in its own README — so `beginRemotePairing`
///   below is a thin wrapper around whatever symbol the `idevice` Swift
///   bindings end up exposing for it; treat the body as a TODO to fill in
///   against the version of `idevice`/`StikJIT.xcframework` you vendor,
///   rather than a guaranteed-correct call.
/// - **iOS 26 and earlier**: there's no in-Settings UI, so this falls back
///   to importing an existing `.mobiledevicepairing` / `.plist` pairing
///   file (the same file StikDebug/Jitterbug/StikJIT all consume), which
///   is a completely ordinary, well-understood plist on disk.
@MainActor
final class PairingManager: ObservableObject {
    @Published private(set) var isPaired = PairingStore.isPaired
    @Published var lastError: String?

    /// PIN to show the user so they can enter it into
    /// Settings → Developer Mode → Pair with… on iOS 27.
    @Published private(set) var displayedPIN: String?

    static let legacyPairingFileType = UTType(filenameExtension: "mobiledevicepairing")
        ?? .propertyList

    /// Starts listening for an iOS 27 in-Settings pairing request and
    /// generates the PIN to display. Call this when the user taps "Pair"
    /// on a device that has the Settings pairing screen.
    func beginRemotePairing() async {
        lastError = nil
        do {
            // TODO: replace with the real idevice/StikJIT remote-pairing
            // call once you've vendored a concrete version of
            // StikJIT.xcframework, e.g. roughly:
            //
            //   let session = try IDeviceRemotePairing.start()
            //   displayedPIN = session.pin
            //   let record = try await session.waitForCompletion()
            //   try PairingStore.save(record)
            //
            // The shape above mirrors Madeira's "pairs with the iPhone it
            // runs on ... tap Pair with Madeira and enter the PIN Madeira
            // shows" flow; the exact symbol names depend on the vendored
            // framework version.
            throw PairingManagerError.remotePairingNotWired
        } catch {
            lastError = String(describing: error)
        }
    }

    /// iOS 26 and earlier fallback: import a pairing file the user obtained
    /// separately (e.g. via `idevice_pair` on a computer, once).
    func importLegacyPairingFile(from url: URL) {
        lastError = nil
        do {
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            guard (try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil
            )) != nil else {
                throw PairingManagerError.notAPlist
            }
            try PairingStore.save(data)
            isPaired = true
        } catch {
            lastError = String(describing: error)
        }
    }

    func forget() {
        PairingStore.clear()
        isPaired = false
        displayedPIN = nil
    }
}

enum PairingManagerError: LocalizedError {
    case remotePairingNotWired
    case notAPlist

    var errorDescription: String? {
        switch self {
        case .remotePairingNotWired:
            return "In-Settings (iOS 27) pairing isn't wired up to a concrete idevice/StikJIT symbol yet — see the TODO in PairingManager.swift. Use \"Import pairing file\" instead for now."
        case .notAPlist:
            return "That file doesn't look like a valid pairing plist."
        }
    }
}
