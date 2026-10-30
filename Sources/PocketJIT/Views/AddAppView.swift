import SwiftUI

struct AddAppView: View {
    @EnvironmentObject private var appsProvider: InstalledAppsProvider
    @Environment(\.dismiss) private var dismiss

    @State private var bundleIdentifier = ""
    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name (e.g. Delta)", text: $displayName)
                    TextField("Bundle identifier (e.g. com.rileytestut.Delta)", text: $bundleIdentifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Only add apps you sideloaded yourself with your own signing identity.")
                }
            }
            .navigationTitle("Add app")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        appsProvider.add(
                            bundleIdentifier: bundleIdentifier,
                            displayName: displayName.isEmpty ? bundleIdentifier : displayName
                        )
                        dismiss()
                    }
                    .disabled(bundleIdentifier.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddAppView().environmentObject(InstalledAppsProvider())
}
