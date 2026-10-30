import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var pairingManager: PairingManager
    @EnvironmentObject private var appsProvider: InstalledAppsProvider
    @EnvironmentObject private var jitClient: JITClient

    @State private var showingPairing = false
    @State private var showingAddApp = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: pairingManager.isPaired ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(pairingManager.isPaired ? .green : .orange)
                        Text(pairingManager.isPaired ? "Paired with this device" : "Not paired yet")
                        Spacer()
                        Button(pairingManager.isPaired ? "Re-pair" : "Pair") {
                            showingPairing = true
                        }
                        .buttonStyle(.bordered)
                    }
                } footer: {
                    Text("One-time setup. On iOS 27: Settings → Privacy & Security → Developer Mode → Pair with…. On iOS 26 and earlier: import a pairing file obtained from a computer once.")
                }

                Section("Sideloaded apps") {
                    if appsProvider.apps.isEmpty {
                        ContentUnavailableView(
                            "No apps added",
                            systemImage: "square.stack.3d.up.slash",
                            description: Text("Add a sideloaded app's bundle identifier to enable JIT for it.")
                        )
                    }
                    ForEach(appsProvider.apps) { app in
                        AppRow(app: app)
                    }
                    .onDelete { indexSet in
                        indexSet.map { appsProvider.apps[$0] }.forEach(appsProvider.remove)
                    }

                    Button {
                        showingAddApp = true
                    } label: {
                        Label("Add app", systemImage: "plus")
                    }
                }

                if let result = jitClient.lastResult {
                    Section("Last result") {
                        Text(result)
                            .font(.callout)
                            .foregroundStyle(result.hasPrefix("Failed") ? .red : .primary)
                    }
                }
            }
            .navigationTitle("PocketJIT")
            .sheet(isPresented: $showingPairing) {
                PairingView()
            }
            .sheet(isPresented: $showingAddApp) {
                AddAppView()
            }
        }
    }
}

private struct AppRow: View {
    let app: SideloadedApp
    @EnvironmentObject private var appsProvider: InstalledAppsProvider
    @EnvironmentObject private var jitClient: JITClient
    @EnvironmentObject private var pairingManager: PairingManager

    @State private var pidText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(app.displayName).font(.headline)
            Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)

            HStack {
                TextField("PID (launch the app first)", text: $pidText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .onAppear { pidText = app.pid.map(String.init) ?? "" }
                Button("Set") {
                    appsProvider.setPID(pid_t(pidText), for: app)
                }
                .buttonStyle(.bordered)
            }

            Button {
                Task { await jitClient.enableJIT(for: app) }
            } label: {
                if jitClient.isEnabling {
                    ProgressView()
                } else {
                    Label("Enable JIT", systemImage: "bolt.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(jitClient.isEnabling || !pairingManager.isPaired || app.pid == nil)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(PairingManager())
        .environmentObject(InstalledAppsProvider())
        .environmentObject(JITClient())
}
