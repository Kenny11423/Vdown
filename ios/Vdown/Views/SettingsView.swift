import SwiftUI

struct SettingsView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @AppStorage("vdown_api_endpoint") private var apiEndpoint: String = "https://api.cobalt.liubquanti.click/"
    @AppStorage("vdown_api_key") private var apiKey: String = ""
    @State private var showClearConfirmation: Bool = false
    @State private var testStatusMessage: String?
    @State private var isTestingAPI: Bool = false

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
                Section(
                    header: Text("Stream Extraction API"),
                    footer: Text("Vdown uses this API endpoint to resolve video streams. If empty or failing, automatic public fallbacks are used. You can also provide an API Key if your instance requires JWT/auth.")
                ) {
                    TextField("API Endpoint URL", text: $apiEndpoint)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.footnote)

                    SecureField("API Key / Bearer Token (Optional)", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.footnote)

                    HStack {
                        Button("Reset Default") {
                            apiEndpoint = "https://api.cobalt.liubquanti.click/"
                            apiKey = ""
                        }

                        Spacer()

                        Button(action: testConnection) {
                            if isTestingAPI {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Test Connection")
                            }
                        }
                        .disabled(isTestingAPI)
                    }

                    if let status = testStatusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(status.contains("OK") ? .green : .red)
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

    private func testConnection() {
        guard let url = URL(string: apiEndpoint.hasSuffix("/") ? apiEndpoint : "\(apiEndpoint)/") else {
            testStatusMessage = "Invalid URL syntax"
            return
        }

        isTestingAPI = true
        testStatusMessage = nil

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue(key, forHTTPHeaderField: "Api-Key")
        }

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                await MainActor.run {
                    self.isTestingAPI = false
                    if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                        self.testStatusMessage = "Connection OK! (HTTP \(http.statusCode))"
                    } else if let http = response as? HTTPURLResponse {
                        self.testStatusMessage = "Failed: HTTP \(http.statusCode)"
                    } else {
                        self.testStatusMessage = "No response from server."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isTestingAPI = false
                    self.testStatusMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
