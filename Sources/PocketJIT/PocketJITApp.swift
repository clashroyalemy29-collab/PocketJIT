import SwiftUI

@main
struct PocketJITApp: App {
    @StateObject private var pairingManager = PairingManager()
    @StateObject private var appsProvider = InstalledAppsProvider()
    @StateObject private var jitClient = JITClient()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pairingManager)
                .environmentObject(appsProvider)
                .environmentObject(jitClient)
        }
    }
}
