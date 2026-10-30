import SwiftUI
import UniformTypeIdentifiers

struct PairingView: View {
    @EnvironmentObject private var pairingManager: PairingManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingFileImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("iOS 27: pair without a computer") {
                    if let pin = pairingManager.displayedPIN {
                        VStack(spacing: 8) {
                            Text("Enter this PIN in Settings")
                                .font(.subheadline)
                            Text(pin)
                                .font(.system(.largeTitle, design: .monospaced))
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }

                    Button {
                        Task { await pairingManager.beginRemotePairing() }
                    } label: {
                        Label("Pair with this device", systemImage: "antenna.radiowaves.left.and.right")
                    }

                    Text("Go to Settings → Privacy & Security → Developer Mode → Pair with…, select PocketJIT, and enter the PIN shown above.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("iOS 26 and earlier: import pairing file") {
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Import pairing file…", systemImage: "doc.badge.plus")
                    }
                    Text("Obtained once from a computer, e.g. via idevice_pair — the same file StikDebug and similar tools use.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = pairingManager.lastError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }

                if pairingManager.isPaired {
                    Section {
                        Button("Forget pairing", role: .destructive) {
                            pairingManager.forget()
                        }
                    }
                }
            }
            .navigationTitle("Pair device")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [PairingManager.legacyPairingFileType, .propertyList],
                onCompletion: { result in
                    if case .success(let url) = result {
                        pairingManager.importLegacyPairingFile(from: url)
                    }
                }
            )
        }
    }
}

#Preview {
    PairingView().environmentObject(PairingManager())
}
