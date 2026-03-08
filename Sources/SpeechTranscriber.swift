import Foundation
import Speech
import AVFoundation

// MARK: - Transcription Result

struct TranscriptionResult: Codable {
    let sourceFile: String
    let text: String
    let transcribedAt: Date
}

// MARK: - Transcription Directory

enum TranscriptionDirectory {
    static var url: URL {
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        return musicDir.appendingPathComponent("Pochi").appendingPathComponent("transcripts")
    }

    static func ensureExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Check if a transcript JSON exists for the given audio filename.
    static func hasTranscript(for audioFilename: String) -> Bool {
        let baseName = (audioFilename as NSString).deletingPathExtension
        let jsonURL = url.appendingPathComponent("\(baseName).json")
        return FileManager.default.fileExists(atPath: jsonURL.path)
    }

    /// Return the transcript JSON URL for the given audio filename.
    static func transcriptURL(for audioFilename: String) -> URL {
        let baseName = (audioFilename as NSString).deletingPathExtension
        return url.appendingPathComponent("\(baseName).json")
    }

    /// Rename transcript JSON when the source audio file is renamed.
    /// Also updates the sourceFile field inside the JSON.
    static func renameTranscript(oldAudioFilename: String, newAudioFilename: String) {
        let fm = FileManager.default
        let oldBase = (oldAudioFilename as NSString).deletingPathExtension
        let newBase = (newAudioFilename as NSString).deletingPathExtension
        let oldJSON = url.appendingPathComponent("\(oldBase).json")
        let newJSON = url.appendingPathComponent("\(newBase).json")

        guard fm.fileExists(atPath: oldJSON.path) else { return }

        // Update sourceFile field inside JSON
        if let data = try? Data(contentsOf: oldJSON) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if var result = try? decoder.decode(TranscriptionResult.self, from: data) {
                result = TranscriptionResult(
                    sourceFile: newAudioFilename,
                    text: result.text,
                    transcribedAt: result.transcribedAt
                )
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let newData = try? encoder.encode(result) {
                    try? newData.write(to: oldJSON, options: .atomic)
                }
            }
        }

        // Rename file
        try? fm.moveItem(at: oldJSON, to: newJSON)
    }
}

// MARK: - Speech Transcriber

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case authorizationDenied
    case fileNotFound(String)
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available for Japanese."
        case .authorizationDenied:
            return "Speech recognition authorization was denied."
        case .fileNotFound(let name):
            return "Audio file not found: \(name)"
        case .recognitionFailed(let reason):
            return "Recognition failed: \(reason)"
        }
    }
}

class SpeechTranscriber {
    private let recognizer: SFSpeechRecognizer
    private let chunkDuration: TimeInterval = 55.0

    init() throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP")),
              recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        self.recognizer = recognizer
    }

    // MARK: - Cache

    private func cacheURL(for filename: String) -> URL {
        let baseName = (filename as NSString).deletingPathExtension
        return TranscriptionDirectory.url.appendingPathComponent("\(baseName).json")
    }

    func cachedResult(for filename: String) -> TranscriptionResult? {
        let url = cacheURL(for: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TranscriptionResult.self, from: data)
    }

    // MARK: - Main Transcribe Method

    func transcribe(filename: String) async throws -> TranscriptionResult {
        // Check cache first
        if let cached = cachedResult(for: filename) {
            return cached
        }

        // Request authorization
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard status == .authorized else {
            throw TranscriptionError.authorizationDenied
        }

        // Verify file exists
        let fileURL = PochiDirectory.url.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw TranscriptionError.fileNotFound(filename)
        }

        // Get audio duration
        let asset = AVURLAsset(url: fileURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        let text: String
        if totalSeconds <= 60.0 {
            // Short audio: recognize directly
            text = try await recognizeSingleFile(url: fileURL)
        } else {
            // Long audio: split into chunks
            text = try await recognizeInChunks(asset: asset, totalSeconds: totalSeconds)
        }

        // Save result
        let result = TranscriptionResult(
            sourceFile: filename,
            text: text,
            transcribedAt: Date()
        )
        saveResult(result, for: filename)
        return result
    }

    // MARK: - Single File Recognition

    private func recognizeSingleFile(url: URL) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !resumed else { return }
                if let error = error {
                    resumed = true
                    continuation.resume(throwing: TranscriptionError.recognitionFailed(error.localizedDescription))
                    return
                }
                if let result = result, result.isFinal {
                    resumed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    // MARK: - Chunked Recognition

    private func recognizeInChunks(asset: AVURLAsset, totalSeconds: Float64) async throws -> String {
        var texts: [String] = []
        var startTime: Float64 = 0

        while startTime < totalSeconds {
            let endTime = min(startTime + chunkDuration, totalSeconds)
            let chunkURL = try await exportChunk(
                asset: asset,
                startSeconds: startTime,
                endSeconds: endTime
            )

            do {
                let chunkText = try await recognizeSingleFile(url: chunkURL)
                if !chunkText.isEmpty {
                    texts.append(chunkText)
                }
            } catch {
                // Continue with remaining chunks even if one fails
                print("Chunk recognition failed at \(startTime)s: \(error.localizedDescription)")
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: chunkURL)

            startTime = endTime
        }

        guard !texts.isEmpty else {
            throw TranscriptionError.recognitionFailed("No text was recognized from any chunk.")
        }

        return texts.joined(separator: "\n")
    }

    private func exportChunk(asset: AVURLAsset, startSeconds: Float64, endSeconds: Float64) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let chunkURL = tempDir.appendingPathComponent("pochi_chunk_\(UUID().uuidString).m4a")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.recognitionFailed("Could not create export session.")
        }

        let startCMTime = CMTime(seconds: startSeconds, preferredTimescale: 44100)
        let endCMTime = CMTime(seconds: endSeconds, preferredTimescale: 44100)
        exportSession.timeRange = CMTimeRange(start: startCMTime, end: endCMTime)
        exportSession.outputURL = chunkURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        guard exportSession.status == .completed else {
            let reason = exportSession.error?.localizedDescription ?? "Unknown export error"
            throw TranscriptionError.recognitionFailed("Chunk export failed: \(reason)")
        }

        return chunkURL
    }

    // MARK: - Save Result

    private func saveResult(_ result: TranscriptionResult, for filename: String) {
        TranscriptionDirectory.ensureExists()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(result) else { return }
        try? data.write(to: cacheURL(for: filename), options: .atomic)
    }
}
