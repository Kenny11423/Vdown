import Foundation

struct ExtractedMedia {
    let downloadURL: URL
    let filename: String
    let isAudio: Bool
}

class VideoExtractor {
    static let shared = VideoExtractor()

    private let directExtensions = [
        "mp4", "m4v", "mov", "mkv", "webm", "avi",
        "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus"
    ]

    func extract(
        from sourceURL: URL,
        quality: VideoQuality,
        customEndpoint: String? = nil
    ) async throws -> ExtractedMedia {
        let pathExtension = sourceURL.pathExtension.lowercased()
        let filenameFromURL = sourceURL.deletingPathExtension().lastPathComponent

        // Case 1: Direct link to media file
        if directExtensions.contains(pathExtension) {
            let cleanTitle = filenameFromURL.isEmpty ? "video" : filenameFromURL
            let finalName = "\(cleanTitle).\(pathExtension)"
            return ExtractedMedia(
                downloadURL: sourceURL,
                filename: sanitizeFilename(finalName),
                isAudio: ["mp3", "m4a", "aac", "wav", "flac", "ogg", "opus"].contains(pathExtension)
            )
        }

        // Case 2: Use video extraction API (Cobalt or user custom endpoint)
        let endpointString = (customEndpoint?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? customEndpoint!
            : (UserDefaults.standard.string(forKey: "vdown_api_endpoint") ?? "https://api.cobalt.tools/api/json")

        guard let apiURL = URL(string: endpointString) else {
            throw NSError(
                domain: "VdownExtractor",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint configuration."]
            )
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 25.0

        var qualityParam = "1080"
        switch quality {
        case .best: qualityParam = "max"
        case .p1080: qualityParam = "1080"
        case .p720: qualityParam = "720"
        case .p480: qualityParam = "480"
        case .p360: qualityParam = "360"
        case .audioOnly: qualityParam = "128"
        }

        let requestPayload: [String: Any] = [
            "url": sourceURL.absoluteString,
            "vQuality": qualityParam,
            "isAudioOnly": quality.isAudio,
            "aFormat": "mp3",
            "filenamePattern": "classic"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestPayload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "VdownExtractor", code: 500, userInfo: [NSLocalizedDescriptionKey: "No response from extractor server."])
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Parse potential error message from JSON
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorObj = json["error"] as? [String: Any],
                   let msg = errorObj["code"] as? String {
                    throw NSError(domain: "VdownExtractor", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Extractor error: \(msg)"])
                }
                throw NSError(domain: "VdownExtractor", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Extraction failed (HTTP \(httpResponse.statusCode)). Use in-app browser tab to capture video."])
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "VdownExtractor", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response."])
            }

            let status = json["status"] as? String ?? ""
            if status == "error" {
                let msg = (json["error"] as? [String: Any])?["code"] as? String ?? "Unknown error"
                throw NSError(domain: "VdownExtractor", code: 400, userInfo: [NSLocalizedDescriptionKey: "Service message: \(msg)"])
            }

            var downloadUrlString: String?
            var resolvedFilename: String = "vdown_media"

            if let urlStr = json["url"] as? String {
                downloadUrlString = urlStr
            } else if let picker = json["picker"] as? [[String: Any]], let first = picker.first, let urlStr = first["url"] as? String {
                downloadUrlString = urlStr
            }

            if let filename = json["filename"] as? String, !filename.isEmpty {
                resolvedFilename = filename
            } else {
                let ext = quality.isAudio ? "mp3" : "mp4"
                resolvedFilename = "Vdown_\(Int(Date().timeIntervalSince1970)).\(ext)"
            }

            guard let finalUrlStr = downloadUrlString, let resolvedURL = URL(string: finalUrlStr) else {
                throw NSError(domain: "VdownExtractor", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find a downloadable stream. Try the Web Browser sniffer tab."])
            }

            return ExtractedMedia(
                downloadURL: resolvedURL,
                filename: sanitizeFilename(resolvedFilename),
                isAudio: quality.isAudio
            )
        } catch {
            throw error
        }
    }

    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let sanitized = filename.components(separatedBy: invalidCharacters).joined(separator: "_")
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
