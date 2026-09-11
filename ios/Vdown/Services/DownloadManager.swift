import Foundation
import Combine
import Photos
import UIKit

class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()

    @Published var activeItem: DownloadItem?
    @Published var isDownloading: Bool = false
    @Published var localFiles: [LocalMediaFile] = []
    @Published var errorMessage: String?
    @Published var downloadSuccessAlert: Bool = false
    @Published var selectedTab: Int = 0
    @Published var snifferURL: String = ""

    private var session: URLSession!
    private var downloadTask: URLSessionDownloadTask?
    private var lastSpeedCheckDate: Date = Date()
    private var bytesSinceLastCheck: Int64 = 0
    private var expectedFilename: String = "video.mp4"

    override init() {
        super.init()
        // Migrate away from broken official domain if stored in UserDefaults
        let currentEndpoint = UserDefaults.standard.string(forKey: "vdown_api_endpoint") ?? ""
        if currentEndpoint.isEmpty || currentEndpoint.contains("api.cobalt.tools") {
            UserDefaults.standard.set("https://api.cobalt.liubquanti.click/", forKey: "vdown_api_endpoint")
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        refreshLocalFiles()
    }

    var downloadDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Vdown", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func startDirectDownload(url: URL, filename: String = "video.mp4") {
        guard !isDownloading else { return }
        errorMessage = nil
        isDownloading = true
        expectedFilename = filename

        let isAudio = filename.lowercased().hasSuffix(".mp3")
        var item = DownloadItem(url: url, title: filename, quality: .best, isAudioOnly: isAudio)
        item.status = .downloading
        self.activeItem = item
        self.lastSpeedCheckDate = Date()
        self.bytesSinceLastCheck = 0

        let task = self.session.downloadTask(with: url)
        self.downloadTask = task
        task.resume()
    }

    func startDownload(url: URL, quality: VideoQuality, isAudio: Bool, customName: String? = nil) {
        guard !isDownloading else { return }

        errorMessage = nil
        isDownloading = true
        var item = DownloadItem(url: url, title: "Fetching stream...", quality: quality, isAudioOnly: isAudio)
        item.status = .extracting
        self.activeItem = item

        Task { @MainActor in
            do {
                let media = try await VideoExtractor.shared.extract(from: url, quality: quality)
                
                let resolvedName: String
                if let custom = customName, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let ext = (media.filename as NSString).pathExtension
                    resolvedName = ext.isEmpty ? "\(custom).mp4" : "\(custom).\(ext)"
                } else {
                    resolvedName = media.filename
                }

                self.expectedFilename = resolvedName
                self.activeItem?.title = resolvedName
                self.activeItem?.status = .downloading
                self.lastSpeedCheckDate = Date()
                self.bytesSinceLastCheck = 0

                let task = self.session.downloadTask(with: media.downloadURL)
                self.downloadTask = task
                task.resume()
            } catch {
                self.isDownloading = false
                self.activeItem?.status = .failed(error.localizedDescription)
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        activeItem?.status = .cancelled
        activeItem = nil
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        bytesSinceLastCheck += bytesWritten
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSpeedCheckDate)

        if elapsed >= 0.8 {
            let speedBytesPerSec = Double(bytesSinceLastCheck) / elapsed
            let speedString = ByteCountFormatter.string(fromByteCount: Int64(speedBytesPerSec), countStyle: .file) + "/s"
            
            self.activeItem?.speedText = speedString
            self.lastSpeedCheckDate = now
            self.bytesSinceLastCheck = 0
        }

        self.activeItem?.downloadedBytes = totalBytesWritten
        self.activeItem?.totalBytes = totalBytesExpectedToWrite

        if totalBytesExpectedToWrite > 0 {
            self.activeItem?.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        var destination = downloadDirectory.appendingPathComponent(expectedFilename)
        
        // Handle name collisions
        var counter = 1
        let originalName = (expectedFilename as NSString).deletingPathExtension
        let ext = (expectedFilename as NSString).pathExtension
        while FileManager.default.fileExists(atPath: destination.path) {
            let newFilename = "\(originalName)_\(counter).\(ext)"
            destination = downloadDirectory.appendingPathComponent(newFilename)
            counter += 1
        }

        do {
            try FileManager.default.moveItem(at: location, to: destination)
            DispatchQueue.main.async {
                self.isDownloading = false
                self.activeItem?.status = .completed
                self.activeItem?.localFileURL = destination
                self.downloadSuccessAlert = true
                self.refreshLocalFiles()
            }
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.activeItem?.status = .failed(error.localizedDescription)
                self.errorMessage = "Failed to save file: \(error.localizedDescription)"
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.activeItem?.status = .failed(error.localizedDescription)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - File Management

    func refreshLocalFiles() {
        let dir = downloadDirectory
        guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: .skipsHiddenFiles) else {
            self.localFiles = []
            return
        }

        let mediaFiles = items.map { LocalMediaFile(fileURL: $0) }
            .sorted { $0.creationDate > $1.creationDate }
        self.localFiles = mediaFiles
    }

    func deleteFile(_ file: LocalMediaFile) {
        try? FileManager.default.removeItem(at: file.fileURL)
        refreshLocalFiles()
    }

    func clearAllFiles() {
        for file in localFiles {
            try? FileManager.default.removeItem(at: file.fileURL)
        }
        refreshLocalFiles()
    }

    var totalStorageUsed: String {
        let total = localFiles.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    // MARK: - Save to Photos

    func saveToPhotos(file: LocalMediaFile, completion: @escaping (Bool, String?) -> Void) {
        guard file.isVideo else {
            completion(false, "Only video files can be saved to Photos library.")
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(false, "Photo Library access was denied in Settings.")
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: file.fileURL)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(true, nil)
                    } else {
                        completion(false, error?.localizedDescription ?? "Failed to save video.")
                    }
                }
            }
        }
    }
}
