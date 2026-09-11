import SwiftUI
import QuickLook

struct DownloadsListView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var searchText: String = ""
    @State private var filterMode: Int = 0 // 0: All, 1: Videos, 2: Audio
    @State private var playingMediaURL: URL?
    @State private var sharingFile: LocalMediaFile?
    @State private var saveAlertMessage: String?
    @State private var showSaveAlert: Bool = false

    var filteredFiles: [LocalMediaFile] {
        downloadManager.localFiles.filter { file in
            let matchesFilter: Bool
            switch filterMode {
            case 1: matchesFilter = file.isVideo
            case 2: matchesFilter = !file.isVideo
            default: matchesFilter = true
            }

            if searchText.isEmpty {
                return matchesFilter
            } else {
                return matchesFilter && file.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Segment
                Picker("Filter", selection: $filterMode) {
                    Text("All (\(downloadManager.localFiles.count))").tag(0)
                    Text("Videos").tag(1)
                    Text("Audio").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if downloadManager.localFiles.isEmpty {
                    emptyStateView
                } else if filteredFiles.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No matching files found")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredFiles) { file in
                            fileRow(file)
                        }
                        .onDelete(perform: deleteFiles)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search downloaded files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { downloadManager.refreshLocalFiles() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $playingMediaURL) { url in
                VideoPlayerView(url: url)
            }
            .sheet(item: $sharingFile) { file in
                ShareSheet(activityItems: [file.fileURL])
            }
            .alert(isPresented: $showSaveAlert) {
                Alert(
                    title: Text("Photos Library"),
                    message: Text(saveAlertMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func fileRow(_ file: LocalMediaFile) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(file.isVideo ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: file.isVideo ? "video.fill" : "music.note")
                    .foregroundColor(file.isVideo ? .blue : .purple)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(file.formattedSize)
                    Text("•")
                    Text(file.formattedDate)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            Menu {
                Button(action: { playingMediaURL = file.fileURL }) {
                    Label("Play / View", systemImage: "play.circle")
                }

                if file.isVideo {
                    Button(action: { saveFileToPhotos(file) }) {
                        Label("Save to Photos", systemImage: "photo.on.rectangle")
                    }
                }

                Button(action: { sharingFile = file }) {
                    Label("Share / Export", systemImage: "square.and.arrow.up")
                }

                Divider()

                Button(role: .destructive, action: { downloadManager.deleteFile(file) }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            playingMediaURL = file.fileURL
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 54))
                .foregroundColor(.secondary)
            Text("No downloads yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Downloaded videos and audio will appear here.\nThey can also be found in the iOS Files app.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = filteredFiles[index]
            downloadManager.deleteFile(file)
        }
    }

    private func saveFileToPhotos(_ file: LocalMediaFile) {
        downloadManager.saveToPhotos(file: file) { success, error in
            if success {
                saveAlertMessage = "Video successfully saved to your Photos library!"
            } else {
                saveAlertMessage = error ?? "Failed to save video to Photos."
            }
            showSaveAlert = true
        }
    }
}

// Extension to make URL Identifiable for sheet presentation
extension URL: Identifiable {
    public var id: String { absoluteString }
}
