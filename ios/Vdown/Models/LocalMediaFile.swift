import Foundation

struct LocalMediaFile: Identifiable, Equatable {
    let id: UUID
    let fileURL: URL
    let name: String
    let size: Int64
    let creationDate: Date
    let isVideo: Bool

    init(fileURL: URL) {
        self.id = UUID()
        self.fileURL = fileURL
        self.name = fileURL.lastPathComponent
        let ext = fileURL.pathExtension.lowercased()
        self.isVideo = ["mp4", "mov", "m4v", "mkv", "webm", "avi"].contains(ext)
        
        let attr = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        self.size = (attr?[.size] as? Int64) ?? 0
        self.creationDate = (attr?[.creationDate] as? Date) ?? Date()
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
}
