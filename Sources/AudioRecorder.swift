import Foundation
import AVFoundation
import IOKit.pwr_mgt
import SwiftUI

struct Recording: Identifiable, Equatable {
    let id = UUID()
    let fileURL: URL
    let createdAt: Date

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
    @Published var audioLevel: Float = 0.0
    @Published var recordings: [Recording] = []

    private var timer: Timer?
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

    func fetchRecordings() {
        let fileManager = FileManager.default
        guard let musicDirectory = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first else { return }
        let pochiDir = musicDirectory.appendingPathComponent("Pochi")

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: pochiDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)

            let audioFiles = fileURLs.filter { ["m4a", "mp3", "wav"].contains($0.pathExtension) }

            DispatchQueue.main.async {
                self.recordings = audioFiles.map { url in
                    let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return Recording(fileURL: url, createdAt: creationDate)
                }.sorted(by: { $0.createdAt > $1.createdAt })
            }
        } catch {
            print("Error fetching recordings: \(error)")
        }
    }

    private func sanitizeFileName(_ name: String) -> String {
        // Remove invalid filename characters: / \ : * ? " < > | and null character
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|\0")
        let sanitized = name.components(separatedBy: invalidCharacters).joined()

        // If the sanitized name is empty, return a default name
        if sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let dateString = formatter.string(from: Date())
            return "\(dateString)-renamed"
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

    func startRecording() {
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
        audioRecorder?.stop()
        isRecording = false
        stopTimer()
        releaseSleep()
        audioLevel = 0.0 // Reset level
        writeStatus()
        print("Recording stopped.")
        fetchRecordings()
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())

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
        // Update at 100ms interval (10 Hz) - good balance between smoothness and CPU usage
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingTime += 0.1

            if let recorder = self.audioRecorder {
                recorder.updateMeters()
                // Normalize power (roughly -160 to 0 dB) to 0.0 - 1.0
                // Typical speech is around -30 to -10.
                let power = recorder.averagePower(forChannel: 0)
                self.audioLevel = self.normalizeSoundLevel(level: power)
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
                self.startRecording()
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
            self?.fetchRecordings()
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
