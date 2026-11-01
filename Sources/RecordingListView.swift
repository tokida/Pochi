import SwiftUI

struct RecordingListView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: Recording Controls
            HStack {
                VStack(alignment: .leading) {
                    Text(audioRecorder.isRecording ? "Recording..." : "Ready to Record")
                        .font(.headline)
                    if audioRecorder.isRecording {
                        HStack(spacing: 4) {
                            Text(timeString(from: audioRecorder.recordingTime))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let stopAt = audioRecorder.autoStopAt {
                                Text("→ \(stopTimeString(from: stopAt))")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                Spacer()

                if audioRecorder.isRecording {
                    Button(action: { audioRecorder.stopRecording() }) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 32, height: 32)
                                .shadow(radius: 1)
                            Image(systemName: "stop.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Menu {
                        Button("通常（無制限）") {
                            audioRecorder.startRecording()
                        }
                        Divider()
                        Button("+15分 (\(relativeStopLabel(minutes: 15))に停止)") {
                            audioRecorder.startRecording(stopAt: Date().addingTimeInterval(15 * 60))
                        }
                        Button("+30分 (\(relativeStopLabel(minutes: 30))に停止)") {
                            audioRecorder.startRecording(stopAt: Date().addingTimeInterval(30 * 60))
                        }
                        Button("+60分 (\(relativeStopLabel(minutes: 60))に停止)") {
                            audioRecorder.startRecording(stopAt: Date().addingTimeInterval(60 * 60))
                        }
                        Divider()
                        ForEach(nextLandmarkTimes(), id: \.self) { date in
                            Button("\(stopTimeString(from: date))まで") {
                                audioRecorder.startRecording(stopAt: date)
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                                .shadow(radius: 1)
                            Image(systemName: "circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // List of Recordings
            if audioRecorder.recordings.isEmpty {
                VStack {
                    Spacer()
                    Text("No recordings yet")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(minHeight: 200)
            } else {
                List {
                    ForEach(audioRecorder.recordings) { recording in
                        RecordingRow(
                            audioRecorder: audioRecorder,
                            recording: recording,
                            isTranscribing: audioRecorder.transcribingFiles.contains(recording.fileName),
                            isTranscribed: audioRecorder.transcribedFiles.contains(recording.fileName)
                        )
                    }
                    .onDelete(perform: audioRecorder.deleteRecording)
                }
                .listStyle(.plain)
                .frame(minHeight: 200, maxHeight: 400)
            }
            
            Divider()
            
            // Shortcut hints
            HStack(spacing: 12) {
                Label("⌘⌥R Record", systemImage: "mic.fill")
                Label("⌘⌥P Panel", systemImage: "macwindow")
            }
            .font(.caption2)
            .foregroundColor(Color(NSColor.tertiaryLabelColor))
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)

            // Footer (Actions & Settings)
            HStack {
                Button(action: {
                    audioRecorder.openFolder()
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("Open Recordings Folder")

                Spacer()

                Menu {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { settingsManager.isLaunchAtLoginEnabled },
                        set: { settingsManager.toggleLaunchAtLogin(enabled: $0) }
                    ))

                    Toggle("Show Timer in Menu Bar", isOn: $settingsManager.showTimerInMenuBar)

                    Divider()

                    Button("Quit Pochi") {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize() // Prevents expansion
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 320)
    }
    
    func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func stopTimeString(from date: Date) -> String {
        Formatters.hhmm.string(from: date)
    }

    func relativeStopLabel(minutes: Int) -> String {
        let date = Date().addingTimeInterval(TimeInterval(minutes * 60))
        return stopTimeString(from: date)
    }

    // 現在時刻から次の :00/:15/:30 境界を最大3つ返す（5分未満はスキップ）
    func nextLandmarkTimes() -> [Date] {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        guard let hour = components.hour, components.minute != nil,
              let year = components.year, let month = components.month, let day = components.day else {
            return []
        }

        var candidates: [Date] = []
        // :00, :15, :30, :45, 次の :00 ... を順に生成してフィルタ
        for offsetHour in 0...2 {
            for quarterMinute in [0, 15, 30, 45] {
                var dc = DateComponents()
                dc.year = year; dc.month = month; dc.day = day
                dc.hour = hour + offsetHour
                dc.minute = quarterMinute
                dc.second = 0
                if let candidate = calendar.date(from: dc),
                   candidate.timeIntervalSince(now) >= 5 * 60 {
                    candidates.append(candidate)
                }
            }
        }

        // 重複除去・昇順ソートして最初の3件
        let sorted = Array(Set(candidates)).sorted()
        // :00, :15, :30 のみ（:45 は除外）
        let filtered = sorted.filter {
            let m = calendar.component(.minute, from: $0)
            return m == 0 || m == 15 || m == 30
        }
        return Array(filtered.prefix(3))
    }
}

struct RecordingRow: View {
    // Not observed: rows only call actions on it. State arrives as plain values so a row
    // re-renders only when its own inputs change, not on every recorder publish.
    let audioRecorder: AudioRecorder
    let recording: Recording
    let isTranscribing: Bool
    let isTranscribed: Bool
    @State private var filename: String

    init(audioRecorder: AudioRecorder, recording: Recording, isTranscribing: Bool, isTranscribed: Bool) {
        self.audioRecorder = audioRecorder
        self.recording = recording
        self.isTranscribing = isTranscribing
        self.isTranscribed = isTranscribed
        _filename = State(initialValue: recording.fileNameWithoutExtension)
    }

    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(.secondary)

            TextField("Filename", text: $filename, onCommit: {
                if filename != recording.fileNameWithoutExtension {
                    audioRecorder.renameRecording(recording, newName: filename)
                }
            })
            .textFieldStyle(.plain)

            Spacer()

            // txt badge
            Button(action: {
                if isTranscribed {
                    let url = TranscriptionDirectory.transcriptURL(for: recording.fileName)
                    NSWorkspace.shared.open(url)
                } else if !isTranscribing {
                    audioRecorder.transcribeRecording(fileName: recording.fileName)
                }
            }) {
                HStack(spacing: 2) {
                    if isTranscribing {
                        ProgressView()
                            .controlSize(.mini)
                    }
                    Text("txt")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(isTranscribing ? .accentColor : (isTranscribed ? .primary : Color(NSColor.tertiaryLabelColor)))
            .disabled(isTranscribing)

            // Duration
            if let duration = recording.duration {
                Text(durationString(from: duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Extension
            Text(recording.fileURL.pathExtension)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func durationString(from interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}