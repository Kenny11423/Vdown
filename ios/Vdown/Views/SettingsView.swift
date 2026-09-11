import SwiftUI

struct SettingsView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @AppStorage("vdown_api_endpoint") private var apiEndpoint: String = "https://api.cobalt.tools/api/json"
    @State private var showClearConfirmation: Bool = false

    var body: some View {
        NavigationView {
            Form {
                // Storage Section
                Section(header: Text("Storage")) {
                    HStack {
                        Label("Downloads Size", systemImage: "internaldrive")
                        Spacer()
                        Text(downloadManager.totalStorageUsed)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Total Files", systemImage: "doc.on.doc")
                        Spacer()
                        Text("\(downloadManager.localFiles.count)")
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive, action: { showClearConfirmation = true }) {
                        Label("Delete All Downloads", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(downloadManager.localFiles.isEmpty)
                }

                // iOS Files Integration
                Section(header: Text("iOS Files Integration")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Files App Access Enabled")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("All videos and songs are saved inside your device's Documents folder. Open the native **Files** app on iOS, go to **On My iPhone -> Vdown** to view, copy, or move them anywhere.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // API Endpoint Section
                Section(header: Text("Stream Extraction API"), footer: Text("Vdown uses this API endpoint to resolve video and audio streams from media platforms. You can supply your own self-hosted backend.")) {
                    TextField("API Endpoint URL", text: $apiEndpoint)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.footnote)

                    Button("Reset to Default API") {
                        apiEndpoint = "https://api.cobalt.tools/api/json"
                    }
                }

                // Sideloading Info
                Section(header: Text("Installation & Sideloading")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TrollStore (Recommended)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("If your device supports TrollStore (iOS 14.0 - 17.0), open the unsigned .ipa directly in TrollStore for permanent installation with no expiration.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("AltStore / SideStore / Sideloadly")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Install the .ipa using your free Apple ID. Re-sign every 7 days or use SideStore for on-device automatic refreshes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                // About Section
                Section(header: Text("About")) {
                    HStack {
                        Text("Application")
                        Spacer()
                        Text("Vdown for iOS")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/Kenny11423/Vdown")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Are you sure you want to delete all downloaded files?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    downloadManager.clearAllFiles()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
