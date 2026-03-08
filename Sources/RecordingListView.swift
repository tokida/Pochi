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
                        Text(timeString(from: audioRecorder.recordingTime))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                    } else {
                        audioRecorder.startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.white)
                            .frame(width: 32, height: 32)
                            .shadow(radius: 1)
                        
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "circle.fill")
                            .foregroundColor(audioRecorder.isRecording ? .white : .red)
                            .font(.system(size: 14))
                    }
                }
                .buttonStyle(.plain)
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
                        RecordingRow(audioRecorder: audioRecorder, recording: recording)
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
}

struct RecordingRow: View {
    @ObservedObject var audioRecorder: AudioRecorder
    let recording: Recording
    @State private var filename: String

    private var isTranscribing: Bool { audioRecorder.transcribingFiles.contains(recording.fileName) }
    private var isTranscribed: Bool { audioRecorder.transcribedFiles.contains(recording.fileName) }

    init(audioRecorder: AudioRecorder, recording: Recording) {
        self.audioRecorder = audioRecorder
        self.recording = recording
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