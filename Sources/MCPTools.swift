import Foundation
import MCP
import AVFoundation

// MARK: - Notification Names (shared between GUI and MCP)

enum PochiNotification {
    static let startRecording = NSNotification.Name("com.example.Pochi.startRecording")
    static let stopRecording = NSNotification.Name("com.example.Pochi.stopRecording")
}

// MARK: - Status File (written by GUI, read by MCP)

struct PochiStatus: Codable {
    var isRecording: Bool
    var currentFile: String?
    var startedAt: Date?

    static var fileURL: URL {
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        return musicDir.appendingPathComponent("Pochi").appendingPathComponent(".pochi-status.json")
    }

    static func read() -> PochiStatus? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PochiStatus.self, from: data)
    }

    func write() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: PochiStatus.fileURL, options: .atomic)
    }
}

// MARK: - Pochi Directory Helper

enum PochiDirectory {
    static var url: URL {
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        return musicDir.appendingPathComponent("Pochi")
    }

    static func ensureExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Tool Handler

class PochiToolHandler {

    // MARK: Tool Definitions

    static func buildTools() -> [Tool] {
        [
            Tool(
                name: "start_recording",
                description: "Start audio recording via Pochi GUI app. The Pochi GUI app must be running.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                ])
            ),
            Tool(
                name: "stop_recording",
                description: "Stop the current audio recording via Pochi GUI app.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                ])
            ),
            Tool(
                name: "get_recording_status",
                description: "Get the current recording status (is recording, current file, etc).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                ])
            ),
            Tool(
                name: "list_recordings",
                description: "List audio recordings in the Pochi recordings folder (~/Music/Pochi/).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "limit": .object([
                            "type": .string("integer"),
                            "description": .string("Maximum number of recordings to return. Default is 20."),
                        ]),
                        "date": .object([
                            "type": .string("string"),
                            "description": .string("Filter by date in YYYYMMDD format. Only returns recordings from that date."),
                        ]),
                    ]),
                ])
            ),
            Tool(
                name: "get_recording_info",
                description: "Get detailed information about a specific recording (size, duration, creation date).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "filename": .object([
                            "type": .string("string"),
                            "description": .string("The filename of the recording (e.g. '20260205-01.m4a')."),
                        ]),
                    ]),
                    "required": .array([.string("filename")]),
                ])
            ),
            Tool(
                name: "rename_recording",
                description: "Rename a recording file. Extension is preserved automatically.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "filename": .object([
                            "type": .string("string"),
                            "description": .string("Current filename of the recording."),
                        ]),
                        "new_name": .object([
                            "type": .string("string"),
                            "description": .string("New name for the recording (without extension)."),
                        ]),
                    ]),
                    "required": .array([.string("filename"), .string("new_name")]),
                ])
            ),
            Tool(
                name: "delete_recording",
                description: "Move a recording to the Trash (recoverable via Finder).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "filename": .object([
                            "type": .string("string"),
                            "description": .string("Filename of the recording to delete."),
                        ]),
                    ]),
                    "required": .array([.string("filename")]),
                ])
            ),
            Tool(
                name: "search_recordings",
                description: "Search recordings by filename pattern.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("Search query. Matches against filename (case-insensitive)."),
                        ]),
                    ]),
                    "required": .array([.string("query")]),
                ])
            ),
        ]
    }

    // MARK: Tool Dispatch

    func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        switch params.name {
        case "start_recording":
            return await handleStartRecording()
        case "stop_recording":
            return await handleStopRecording()
        case "get_recording_status":
            return handleGetRecordingStatus()
        case "list_recordings":
            return handleListRecordings(params: params)
        case "get_recording_info":
            return await handleGetRecordingInfo(params: params)
        case "rename_recording":
            return handleRenameRecording(params: params)
        case "delete_recording":
            return handleDeleteRecording(params: params)
        case "search_recordings":
            return handleSearchRecordings(params: params)
        default:
            return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
        }
    }

    // MARK: - Recording Control (via NSDistributedNotification → GUI)

    private func handleStartRecording() async -> CallTool.Result {
        // Check if already recording
        if let status = PochiStatus.read(), status.isRecording {
            return .init(
                content: [.text("Already recording: \(status.currentFile ?? "unknown")")],
                isError: false
            )
        }

        // Send notification to GUI process
        DistributedNotificationCenter.default().postNotificationName(
            PochiNotification.startRecording,
            object: nil
        )

        // Poll status file for confirmation (up to 3 seconds)
        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if let status = PochiStatus.read(), status.isRecording {
                return .init(
                    content: [.text("Recording started: \(status.currentFile ?? "unknown")")],
                    isError: false
                )
            }
        }

        return .init(
            content: [.text("Recording command sent, but could not confirm. Is the Pochi GUI app running?")],
            isError: false
        )
    }

    private func handleStopRecording() async -> CallTool.Result {
        // Check if actually recording
        if let status = PochiStatus.read(), !status.isRecording {
            return .init(content: [.text("Not currently recording.")], isError: false)
        }

        // Send notification to GUI process
        DistributedNotificationCenter.default().postNotificationName(
            PochiNotification.stopRecording,
            object: nil
        )

        // Poll status file for confirmation (up to 3 seconds)
        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if let status = PochiStatus.read(), !status.isRecording {
                return .init(
                    content: [.text("Recording stopped.")],
                    isError: false
                )
            }
        }

        return .init(
            content: [.text("Stop command sent, but could not confirm.")],
            isError: false
        )
    }

    private func handleGetRecordingStatus() -> CallTool.Result {
        guard let status = PochiStatus.read() else {
            return .init(
                content: [.text("No status available. The Pochi GUI app may not be running.")],
                isError: false
            )
        }

        var lines: [String] = []
        lines.append("Recording: \(status.isRecording ? "Yes" : "No")")
        if let file = status.currentFile {
            lines.append("Current file: \(file)")
        }
        if let startedAt = status.startedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            lines.append("Started at: \(formatter.string(from: startedAt))")
        }

        return .init(content: [.text(lines.joined(separator: "\n"))], isError: false)
    }

    // MARK: - File Management (direct filesystem access, no GUI needed)

    private func handleListRecordings(params: CallTool.Parameters) -> CallTool.Result {
        let limit = Int(params.arguments?["limit"] ?? .null, strict: false) ?? 20
        let dateFilter = params.arguments?["date"]?.stringValue

        let fm = FileManager.default
        let dir = PochiDirectory.url

        guard let fileURLs = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return .init(content: [.text("No recordings found or directory does not exist.")], isError: false)
        }

        var recordings = fileURLs
            .filter { ["m4a", "mp3", "wav"].contains($0.pathExtension.lowercased()) }
            .compactMap { url -> (URL, Date, Int)? in
                let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                let date = values?.creationDate ?? Date.distantPast
                let size = values?.fileSize ?? 0
                return (url, date, size)
            }
            .sorted { $0.1 > $1.1 } // newest first

        // Apply date filter
        if let dateFilter = dateFilter {
            recordings = recordings.filter { $0.0.lastPathComponent.hasPrefix(dateFilter) }
        }

        // Apply limit
        let limited = recordings.prefix(Int(limit))

        if limited.isEmpty {
            return .init(content: [.text("No recordings found.")], isError: false)
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        var lines: [String] = ["Found \(recordings.count) recording(s):"]
        for (url, date, size) in limited {
            let sizeMB = String(format: "%.1f MB", Double(size) / 1_048_576.0)
            lines.append("  \(url.lastPathComponent)  (\(sizeMB), \(formatter.string(from: date)))")
        }
        if recordings.count > Int(limit) {
            lines.append("  ... and \(recordings.count - Int(limit)) more")
        }

        return .init(content: [.text(lines.joined(separator: "\n"))], isError: false)
    }

    private func handleGetRecordingInfo(params: CallTool.Parameters) async -> CallTool.Result {
        guard let filename = params.arguments?["filename"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: filename")], isError: true)
        }

        let fileURL = PochiDirectory.url.appendingPathComponent(filename)
        let fm = FileManager.default

        guard fm.fileExists(atPath: fileURL.path) else {
            return .init(content: [.text("File not found: \(filename)")], isError: true)
        }

        var lines: [String] = ["File: \(filename)"]

        // File size and creation date
        if let values = try? fileURL.resourceValues(forKeys: Set<URLResourceKey>([.creationDateKey, .fileSizeKey])) {
            if let size = values.fileSize {
                lines.append("Size: \(String(format: "%.2f MB", Double(size) / 1_048_576.0))")
            }
            if let date = values.creationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                formatter.timeStyle = .long
                lines.append("Created: \(formatter.string(from: date))")
            }
        }

        // Audio duration via AVFoundation
        let asset = AVURLAsset(url: fileURL)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite {
                let minutes = Int(seconds) / 60
                let secs = Int(seconds) % 60
                lines.append("Duration: \(String(format: "%02d:%02d", minutes, secs))")
            }
        } catch {
            lines.append("Duration: unknown")
        }

        return .init(content: [.text(lines.joined(separator: "\n"))], isError: false)
    }

    private func handleRenameRecording(params: CallTool.Parameters) -> CallTool.Result {
        guard let filename = params.arguments?["filename"]?.stringValue,
              let newName = params.arguments?["new_name"]?.stringValue else {
            return .init(content: [.text("Missing required parameters: filename, new_name")], isError: true)
        }

        let fm = FileManager.default
        let dir = PochiDirectory.url
        let oldURL = dir.appendingPathComponent(filename)

        guard fm.fileExists(atPath: oldURL.path) else {
            return .init(content: [.text("File not found: \(filename)")], isError: true)
        }

        // Sanitize new name
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|\0")
        let sanitized = newName.components(separatedBy: invalidChars).joined()
        guard !sanitized.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
            return .init(content: [.text("Invalid new name.")], isError: true)
        }

        // Preserve original extension
        let ext = oldURL.pathExtension
        let newURL = dir.appendingPathComponent(sanitized).appendingPathExtension(ext)

        guard !fm.fileExists(atPath: newURL.path) else {
            return .init(content: [.text("A file with name '\(sanitized).\(ext)' already exists.")], isError: true)
        }

        do {
            try fm.moveItem(at: oldURL, to: newURL)
            return .init(content: [.text("Renamed: \(filename) -> \(newURL.lastPathComponent)")], isError: false)
        } catch {
            return .init(content: [.text("Rename failed: \(error.localizedDescription)")], isError: true)
        }
    }

    private func handleDeleteRecording(params: CallTool.Parameters) -> CallTool.Result {
        guard let filename = params.arguments?["filename"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: filename")], isError: true)
        }

        let fm = FileManager.default
        let fileURL = PochiDirectory.url.appendingPathComponent(filename)

        guard fm.fileExists(atPath: fileURL.path) else {
            return .init(content: [.text("File not found: \(filename)")], isError: true)
        }

        do {
            // Move to Finder Trash (recoverable)
            try fm.trashItem(at: fileURL, resultingItemURL: nil)
            return .init(content: [.text("Moved to Trash: \(filename)")], isError: false)
        } catch {
            return .init(content: [.text("Delete failed: \(error.localizedDescription)")], isError: true)
        }
    }

    private func handleSearchRecordings(params: CallTool.Parameters) -> CallTool.Result {
        guard let query = params.arguments?["query"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: query")], isError: true)
        }

        let fm = FileManager.default
        let dir = PochiDirectory.url

        guard let fileURLs = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return .init(content: [.text("No recordings found.")], isError: false)
        }

        let lowercaseQuery = query.lowercased()
        let matches = fileURLs
            .filter { ["m4a", "mp3", "wav"].contains($0.pathExtension.lowercased()) }
            .filter { $0.lastPathComponent.lowercased().contains(lowercaseQuery) }
            .compactMap { url -> (URL, Date, Int)? in
                let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                let date = values?.creationDate ?? Date.distantPast
                let size = values?.fileSize ?? 0
                return (url, date, size)
            }
            .sorted { $0.1 > $1.1 }

        if matches.isEmpty {
            return .init(content: [.text("No recordings matching '\(query)'.")], isError: false)
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        var lines: [String] = ["Found \(matches.count) matching recording(s):"]
        for (url, date, size) in matches {
            let sizeMB = String(format: "%.1f MB", Double(size) / 1_048_576.0)
            lines.append("  \(url.lastPathComponent)  (\(sizeMB), \(formatter.string(from: date)))")
        }

        return .init(content: [.text(lines.joined(separator: "\n"))], isError: false)
    }
}

// MARK: - Value extension for integer extraction

private extension Value {
    var integerValue: Int? {
        switch self {
        case .int(let v): return v
        case .double(let v): return Int(v)
        case .string(let v): return Int(v)
        default: return nil
        }
    }
}
