import Foundation
import AVFoundation
import IOKit.pwr_mgt

class AudioRecorder: NSObject, ObservableObject {
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    
    private var timer: Timer?
    private var sleepAssertionID: IOPMAssertionID = 0
    
    override init() {
        super.init()
        createDirectory()
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
        print("Recording stopped.")
    }
    
    private func getFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "Recording_\(formatter.string(from: Date())).m4a"
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
        // Update more frequently for smooth animation (e.g. 0.1s)
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingTime += 0.05
            
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
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            stopRecording()
        }
    }
}
