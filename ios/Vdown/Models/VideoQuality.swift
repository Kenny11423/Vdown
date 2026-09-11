import Foundation

enum VideoQuality: String, CaseIterable, Identifiable, Codable {
    case best = "best"
    case p1080 = "1080"
    case p720 = "720"
    case p480 = "480"
    case p360 = "360"
    case audioOnly = "audio"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .best:
            return "Best Quality (Max)"
        case .p1080:
            return "Full HD (1080p)"
        case .p720:
            return "HD (720p)"
        case .p480:
            return "SD (480p)"
        case .p360:
            return "Low (360p)"
        case .audioOnly:
            return "Audio Only (MP3)"
        }
    }

    var shortLabel: String {
        switch self {
        case .best: return "Max"
        case .p1080: return "1080p"
        case .p720: return "720p"
        case .p480: return "480p"
        case .p360: return "360p"
        case .audioOnly: return "MP3"
        }
    }

    var isAudio: Bool {
        self == .audioOnly
    }
}
