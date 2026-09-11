import Foundation

enum DownloadStatus: Equatable {
    case idle
    case extracting
    case downloading
    case completed
    case failed(String)
    case cancelled
}

struct DownloadItem: Identifiable, Equatable {
    let id: UUID
    var url: URL
    var title: String
    var quality: VideoQuality
    var isAudioOnly: Bool
    var progress: Double // 0.0 to 1.0
    var downloadedBytes: Int64
    var totalBytes: Int64
    var speedText: String
    var status: DownloadStatus
    var localFileURL: URL?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        url: URL,
        title: String = "Video",
        quality: VideoQuality = .best,
        isAudioOnly: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.quality = quality
        self.isAudioOnly = isAudioOnly
        self.progress = 0.0
        self.downloadedBytes = 0
        self.totalBytes = 0
        self.speedText = ""
        self.status = .idle
        self.localFileURL = nil
        self.createdAt = Date()
    }

    var formattedSize: String {
        let count = totalBytes > 0 ? totalBytes : downloadedBytes
        return ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    var formattedProgress: String {
        String(format: "%.1f%%", progress * 100)
    }

    var statusDescription: String {
        switch status {
        case .idle:
            return "Ready"
        case .extracting:
            return "Fetching stream details..."
        case .downloading:
            return "Downloading (\(formattedProgress))"
        case .completed:
            return "Completed"
        case .failed(let error):
            return "Failed: \(error)"
        case .cancelled:
            return "Cancelled"
        }
    }
}
