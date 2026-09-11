import SwiftUI

struct HomeDownloadView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var urlString: String = ""
    @State private var customFilename: String = ""
    @State private var isAudioOnly: Bool = false
    @State private var selectedQuality: VideoQuality = .best
    @State private var showClipboardNotification: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero Banner
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        
                        Text("Vdown")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        
                        Text("Fast video & audio downloader for iOS")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)

                    // URL Input Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MEDIA URL")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.secondary)

                            TextField("Paste link (YouTube, MP4, TikTok, etc.)", text: $urlString)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)

                            if !urlString.isEmpty {
                                Button(action: { urlString = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }

                            Button(action: pasteFromClipboard) {
                                Text("Paste")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Format & Quality Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("DOWNLOAD PREFERENCES")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        VStack(spacing: 12) {
                            // Mode Picker
                            Picker("Format", selection: $isAudioOnly) {
                                Text("Video (MP4)").tag(false)
                                Text("Audio (MP3)").tag(true)
                            }
                            .pickerStyle(.segmented)

                            if !isAudioOnly {
                                HStack {
                                    Text("Video Quality")
                                        .font(.subheadline)
                                    Spacer()
                                    Picker("Quality", selection: $selectedQuality) {
                                        ForEach(VideoQuality.allCases.filter { !$0.isAudio }) { quality in
                                            Text(quality.title).tag(quality)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .padding(.top, 2)
                            }

                            Divider()

                            HStack {
                                Text("Custom Filename")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                TextField("Optional (e.g. MyVideo)", text: $customFilename)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Download Action Button
                    Button(action: startDownloadAction) {
                        HStack {
                            if downloadManager.isDownloading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 6)
                                Text("Downloading...")
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Start Download")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(downloadButtonColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: Color.blue.opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                    .disabled(downloadManager.isDownloading || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal)

                    // Active Download Progress Card
                    if let item = downloadManager.activeItem {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text(item.statusDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: { downloadManager.cancelDownload() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            }

                            if item.status == .downloading {
                                ProgressView(value: item.progress, total: 1.0)
                                    .tint(.blue)

                                HStack {
                                    Text(item.formattedProgress)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)

                                    if !item.speedText.isEmpty {
                                        Text("• \(item.speedText)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text(item.formattedSize)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }

                    // Cloudflare / Web hint card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(.orange)
                            Text("Bypass Cloudflare / Login?")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Text("If a website blocks direct downloading or presents a captcha, open the **Browser** tab below to solve the challenge and grab the media directly.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Vdown")
            .alert(isPresented: $downloadManager.downloadSuccessAlert) {
                Alert(
                    title: Text("Download Complete"),
                    message: Text("File has been saved to your library. You can view or share it in the Files tab."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var downloadButtonColor: Color {
        if downloadManager.isDownloading || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Color.gray.opacity(0.5)
        }
        return Color.blue
    }

    private func pasteFromClipboard() {
        if let clip = UIPasteboard.general.string {
            urlString = clip.trimmingCharacters(in: .whitespacesAndNewlines)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private func startDownloadAction() {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        let quality = isAudioOnly ? .audioOnly : selectedQuality
        downloadManager.startDownload(
            url: url,
            quality: quality,
            isAudio: isAudioOnly,
            customName: customFilename.isEmpty ? nil : customFilename
        )
    }
}
