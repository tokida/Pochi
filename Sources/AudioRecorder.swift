import Foundation
import AVFoundation
import CoreMedia
import IOKit.pwr_mgt
import SwiftUI
import Speech
import Combine

struct Recording: Identifiable, Equatable {
    // Stable identity so SwiftUI List diffs rows instead of rebuilding them on every fetch.
    var id: URL { fileURL }
    let fileURL: URL
    let createdAt: Date
    let duration: TimeInterval?

    var fileName: String {
        fileURL.lastPathComponent
    }

    var fileNameWithoutExtension: String {
        fileURL.deletingPathExtension().lastPathComponent
    }
}

class AudioRecorder: NSObject, ObservableObject {
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    // Not @Published: 10Hz level updates must not invalidate SwiftUI views observing this object.
    let audioLevel = CurrentValueSubject<Float, Never>(0)
    @Published var recordings: [Recording] = []
    @Published var transcribingFiles: Set<String> = []  // 文字起こし中のファイル名
    @Published var transcribedFiles: Set<String> = []   // 文字起こし済みファイル名
    @Published var autoStopAt: Date? = nil

    private var transcriptionQueue: [String] = []  // 待機中ファイル名
    private var isTranscriptionRunning = false       // 実行中フラグ

    private var timer: Timer?
    private let scanQueue = DispatchQueue(label: "Pochi.recordingScan", qos: .userInitiated)
    private var durationCache: [URL: (modifiedAt: Date, duration: TimeInterval?)] = [:]  // scanQueue only
    private var pendingFetch: DispatchWorkItem?
    private var sleepAssertionID: IOPMAssertionID = 0
    private var directoryWatcher: DispatchSourceFileSystemObject?

    override init() {
        super.init()
        createDirectory()
        fetchRecordings()
        startDirectoryWatching()
        setupDistributedNotifications()
        writeStatus() // Initial status
    }

    deinit {
        directoryWatcher?.cancel()
        // Remove distributed notification observers to prevent memory leak
        DistributedNotificationCenter.default().removeObserver(self)
    }

    private func createDirectory() {
        let fileManager = FileManager.default
        if let musicDirectory = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first {
            let saveUrl = musicDirectory.appendingPathComponent("Pochi")
            if !fileManager.fileExists(atPath: saveUrl.path) {
                do {
                    try fileManager.createDirectory(at: saveUrl, withIntermediateDirectories: true, attributes: nil)
                    print("Created directory: \(saveUrl.path)")
                } catch {
                    print("Error creating directory: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Scans the folder off the main thread. Durations are cached per file and only
    /// re-read when the file's modification date changes.
    func fetchRecordings() {
        scanQueue.async { [weak self] in
            guard let self = self else { return }
            let keys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey]
            let fileURLs: [URL]
            do {
                fileURLs = try FileManager.default.contentsOfDirectory(at: PochiDirectory.url, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)
            } catch {
                print("Error fetching recordings: \(error)")
                return
            }

            let audioFiles = fileURLs.filter { ["m4a", "mp3", "wav"].contains($0.pathExtension.lowercased()) }
            var newCache: [URL: (modifiedAt: Date, duration: TimeInterval?)] = [:]

            let recordings = audioFiles.map { url -> Recording in
                let values = try? url.resourceValues(forKeys: Set(keys))
                let modifiedAt = values?.contentModificationDate ?? .distantPast
                let duration: TimeInterval?
                if let cached = self.durationCache[url], cached.modifiedAt == modifiedAt {
                    duration = cached.duration
                } else {
                    let seconds = CMTimeGetSeconds(AVURLAsset(url: url).duration)
                    duration = seconds.isFinite ? seconds : nil
                }
                newCache[url] = (modifiedAt, duration)
                return Recording(fileURL: url, createdAt: values?.creationDate ?? .distantPast, duration: duration)
            }.sorted(by: { $0.createdAt > $1.createdAt })
            self.durationCache = newCache  // drops entries for deleted/renamed files

            let transcribedBases = TranscriptionDirectory.transcribedBaseNames()
            let transcribed = Set(recordings.map(\.fileName).filter {
                transcribedBases.contains(($0 as NSString).deletingPathExtension)
            })

            DispatchQueue.main.async {
                if self.recordings != recordings { self.recordings = recordings }
                if self.transcribedFiles != transcribed { self.transcribedFiles = transcribed }
            }
        }
    }

    /// Coalesces bursts of directory events (atomic writes, recorder file creation) into one scan.
    private func scheduleFetch() {
        pendingFetch?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.fetchRecordings() }
        pendingFetch = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func sanitizeFileName(_ name: String) -> String {
        // Remove invalid filename characters: / \ : * ? " < > | and null character
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|\0")
        let sanitized = name.components(separatedBy: invalidCharacters).joined()

        // If the sanitized name is empty, return a default name
        if sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(Formatters.yyyyMMdd.string(from: Date()))-renamed"
        }

        return sanitized
    }

    func renameRecording(_ recording: Recording, newName: String) {
        let fileManager = FileManager.default
        let directory = recording.fileURL.deletingLastPathComponent()

        // Sanitize the new name to remove invalid characters
        let sanitizedName = sanitizeFileName(newName)
        let newURL = directory.appendingPathComponent(sanitizedName)

        // Check if extension is missing, append original if so
        var finalURL = newURL
        if newURL.pathExtension.isEmpty {
            finalURL = newURL.appendingPathExtension(recording.fileURL.pathExtension)
        }

        do {
            try fileManager.moveItem(at: recording.fileURL, to: finalURL)
            let oldName = recording.fileURL.lastPathComponent
            let newName = finalURL.lastPathComponent
            TranscriptionDirectory.renameTranscript(
                oldAudioFilename: oldName,
                newAudioFilename: newName
            )
            if transcribingFiles.remove(oldName) != nil {
                transcribingFiles.insert(newName)
            }
            if transcribedFiles.remove(oldName) != nil {
                transcribedFiles.insert(newName)
            }
            fetchRecordings()
        } catch {
            print("Error renaming file: \(error.localizedDescription)")
        }
    }

    func deleteRecording(at offsets: IndexSet) {
        let fileManager = FileManager.default
        offsets.forEach { index in
            let recording = recordings[index]
            do {
                // Move to Trash instead of permanent deletion
                try fileManager.trashItem(at: recording.fileURL, resultingItemURL: nil)
            } catch {
                print("Error deleting file: \(error.localizedDescription)")
            }
        }
        fetchRecordings()
    }

    func openFolder() {
        let fileManager = FileManager.default
        if let musicDirectory = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first {
            let saveUrl = musicDirectory.appendingPathComponent("Pochi")
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: saveUrl.path)
        }
    }

    func transcribeRecording(fileName: String) {
        guard !transcribingFiles.contains(fileName),
              !transcribedFiles.contains(fileName) else { return }
        transcribingFiles.insert(fileName)
        transcriptionQueue.append(fileName)
        processNextTranscription()
    }

    private func processNextTranscription() {
        guard !isTranscriptionRunning, let fileName = transcriptionQueue.first else { return }
        isTranscriptionRunning = true
        transcriptionQueue.removeFirst()
        Task.detached(priority: .utility) { [weak self] in
            do {
                let transcriber = try SpeechTranscriber()
                _ = try await transcriber.transcribe(filename: fileName)
                await MainActor.run {
                    self?.transcribingFiles.remove(fileName)
                    self?.transcribedFiles.insert(fileName)
                    self?.isTranscriptionRunning = false
                    self?.processNextTranscription()
                }
            } catch {
                print("Transcription failed: \(error.localizedDescription)")
                await MainActor.run {
                    self?.transcribingFiles.remove(fileName)
                    self?.isTranscriptionRunning = false
                    self?.processNextTranscription()
                }
            }
        }
    }

    func startRecording(stopAt: Date? = nil) {
        autoStopAt = stopAt
        let fileName = getFileName()
        guard let fileURL = getFileURL(fileName: fileName) else { return }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true // Enable audio level metering
            audioRecorder?.prepareToRecord()

            if audioRecorder?.record() == true {
                isRecording = true
                startTimer()
                preventSleep()
                writeStatus(currentFile: fileName)
                print("Recording started: \(fileURL.path)")
            }
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        let recordedFileURL = audioRecorder?.url
        audioRecorder?.stop()
        isRecording = false
        autoStopAt = nil
        stopTimer()
        releaseSleep()
        audioLevel.send(0) // Reset level
        writeStatus()
        print("Recording stopped.")
        fetchRecordings()

        // Auto-transcription in background (non-blocking)
        if let fileURL = recordedFileURL {
            transcribeRecording(fileName: fileURL.lastPathComponent)
        }
    }

    private func getNextSequenceNumber(for dateString: String) -> Int {
        let fileManager = FileManager.default
        guard let musicDirectory = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first else { return 1 }
        let pochiDir = musicDirectory.appendingPathComponent("Pochi")

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: pochiDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

            // Filter files that start with the date string (e.g., "20251225-")
            let pattern = "^\(dateString)-(\\d+)\\."
            let regex = try NSRegularExpression(pattern: pattern, options: [])

            var maxSequence = 0
            for fileURL in fileURLs {
                let filename = fileURL.lastPathComponent
                let nsFilename = filename as NSString
                let matches = regex.matches(in: filename, options: [], range: NSRange(location: 0, length: nsFilename.length))

                if let match = matches.first, match.numberOfRanges > 1 {
                    let sequenceRange = match.range(at: 1)
                    let sequenceString = nsFilename.substring(with: sequenceRange)
                    if let sequence = Int(sequenceString) {
                        maxSequence = max(maxSequence, sequence)
                    }
                }
            }

            return maxSequence + 1
        } catch {
            print("Error scanning directory for sequence number: \(error)")
            return 1
        }
    }

    private func getFileName() -> String {
        let dateString = Formatters.yyyyMMdd.string(from: Date())
        let sequenceNumber = getNextSequenceNumber(for: dateString)
        return "\(dateString)-\(String(format: "%02d", sequenceNumber)).m4a"
    }

    private func getFileURL(fileName: String) -> URL? {
        let fileManager = FileManager.default
        if let musicDirectory = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first {
            return musicDirectory.appendingPathComponent("Pochi").appendingPathComponent(fileName)
        }
        return nil
    }

    private func startTimer() {
        recordingTime = 0
        let startedAt = Date()
        // Meter at 10 Hz; publish only when values visibly change.
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()

            // Wall-clock based (no drift), whole seconds only -> views re-render at 1 Hz
            let elapsed = now.timeIntervalSince(startedAt).rounded(.down)
            if elapsed != self.recordingTime { self.recordingTime = elapsed }

            if let stopAt = self.autoStopAt, now >= stopAt {
                self.stopRecording()
                return
            }

            if let recorder = self.audioRecorder {
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                // Quantize to 0.1 steps so unchanged levels are dropped downstream
                let level = (self.normalizeSoundLevel(level: power) * 10).rounded() / 10
                if level != self.audioLevel.value { self.audioLevel.send(level) }
            }
        }
    }

    private func normalizeSoundLevel(level: Float) -> Float {
        let minDb: Float = -60.0
        if level < minDb { return 0.0 }
        if level >= 0.0 { return 1.0 }
        return (level - minDb) / abs(minDb)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingTime = 0
    }

    // Prevent system sleep during recording
    private func preventSleep() {
        let reasonForActivity = "Recording Audio" as CFString
        var assertionID: IOPMAssertionID = 0
        let success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep as CFString,
                                                  UInt32(kIOPMAssertionLevelOn),
                                                  reasonForActivity,
                                                  &assertionID)
        if success == kIOReturnSuccess {
            sleepAssertionID = assertionID
        }
    }

    private func releaseSleep() {
        if sleepAssertionID != 0 {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
    }

    // MARK: - MCP Integration: Status File

    private func writeStatus(currentFile: String? = nil) {
        let status = PochiStatus(
            isRecording: isRecording,
            currentFile: currentFile ?? audioRecorder?.url.lastPathComponent,
            startedAt: isRecording ? Date() : nil
        )
        status.write()
    }

    // MARK: - MCP Integration: Distributed Notifications

    private func setupDistributedNotifications() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleMCPStartRecording),
            name: PochiNotification.startRecording,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleMCPStopRecording),
            name: PochiNotification.stopRecording,
            object: nil
        )
    }

    @objc private func handleMCPStartRecording(_ notification: Notification) {
        DispatchQueue.main.async {
            if !self.isRecording {
                var stopAt: Date? = nil
                if let ts = notification.object as? String, let interval = Double(ts) {
                    stopAt = Date(timeIntervalSince1970: interval)
                }
                self.startRecording(stopAt: stopAt)
            }
        }
    }

    @objc private func handleMCPStopRecording(_ notification: Notification) {
        DispatchQueue.main.async {
            if self.isRecording {
                self.stopRecording()
            }
        }
    }

    // MARK: - Directory Watching (auto-refresh when MCP modifies files)

    private func startDirectoryWatching() {
        let dir = PochiDirectory.url
        PochiDirectory.ensureExists()

        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleFetch()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        directoryWatcher = source
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            stopRecording()
        }
    }
}
