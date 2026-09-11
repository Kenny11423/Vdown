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

    private let fallbackEndpoints = [
        "https://api.cobalt.liubquanti.click/",
        "https://melon.clxxped.lol/",
        "https://api.cobalt.tools/"
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

        // Case 2: Resolve stream via Cobalt v10/v11 API
        var endpointsToTry: [String] = []

        // Custom endpoint from user configuration
        let userConfigured = customEndpoint?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? UserDefaults.standard.string(forKey: "vdown_api_endpoint")?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let custom = userConfigured, !custom.isEmpty {
            endpointsToTry.append(ensureTrailingSlash(custom))
        }

        // Add fallbacks
        for fb in fallbackEndpoints {
            if !endpointsToTry.contains(fb) {
                endpointsToTry.append(fb)
            }
        }

        var lastError: Error? = nil

        var qualityParam = "1080"
        switch quality {
        case .best: qualityParam = "max"
        case .p1080: qualityParam = "1080"
        case .p720: qualityParam = "720"
        case .p480: qualityParam = "480"
        case .p360: qualityParam = "360"
        case .audioOnly: qualityParam = "128"
        }

        // Standard Cobalt v10 / v11 schema
        let downloadMode = quality.isAudio ? "audio" : "auto"
        let requestPayload: [String: Any] = [
            "url": sourceURL.absoluteString,
            "videoQuality": qualityParam,
            "downloadMode": downloadMode,
            "audioFormat": "mp3",
            "filenameStyle": "classic"
        ]

        guard let payloadData = try? JSONSerialization.data(withJSONObject: requestPayload) else {
            throw NSError(domain: "VdownExtractor", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to construct request payload."])
        }

        let customApiKey = UserDefaults.standard.string(forKey: "vdown_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines)

        for endpointStr in endpointsToTry {
            guard let apiURL = URL(string: endpointStr) else { continue }

            var request = URLRequest(url: apiURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 20.0
            request.httpBody = payloadData

            if let apiKey = customApiKey, !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    continue
                }

                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let status = json["status"] as? String ?? ""

                        if status == "error" {
                            let errorObj = json["error"] as? [String: Any]
                            let code = errorObj?["code"] as? String ?? "unknown"
                            lastError = NSError(domain: "VdownExtractor", code: 400, userInfo: [NSLocalizedDescriptionKey: "Service error: \(code)"])
                            continue
                        }

                        var downloadUrlString: String?
                        if let urlStr = json["url"] as? String {
                            downloadUrlString = urlStr
                        } else if let picker = json["picker"] as? [[String: Any]], let first = picker.first, let urlStr = first["url"] as? String {
                            downloadUrlString = urlStr
                        }

                        if let target = downloadUrlString, let resolvedURL = URL(string: target) {
                            var filename = json["filename"] as? String ?? ""
                            if filename.isEmpty {
                                let ext = quality.isAudio ? "mp3" : "mp4"
                                filename = "Vdown_\(Int(Date().timeIntervalSince1970)).\(ext)"
                            }

                            return ExtractedMedia(
                                downloadURL: resolvedURL,
                                filename: sanitizeFilename(filename),
                                isAudio: quality.isAudio
                            )
                        }
                    }
                } else {
                    // Try parsing JSON error code from 4xx/5xx response
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorObj = json["error"] as? [String: Any],
                       let code = errorObj["code"] as? String {
                        lastError = NSError(domain: "VdownExtractor", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API [\(code)]"])
                    } else {
                        lastError = NSError(domain: "VdownExtractor", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                    }
                }
            } catch {
                lastError = error
            }
        }

        let desc = lastError?.localizedDescription ?? "Extraction servers unavailable."
        throw NSError(
            domain: "VdownExtractor",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "\(desc). Tip: Tap 'Open in Browser' to capture the video directly!"]
        )
    }

    private func ensureTrailingSlash(_ url: String) -> String {
        return url.hasSuffix("/") ? url : "\(url)/"
    }

    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let sanitized = filename.components(separatedBy: invalidCharacters).joined(separator: "_")
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
