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
    
    init(audioRecorder: AudioRecorder, recording: Recording) {
        self.audioRecorder = audioRecorder
        self.recording = recording
        // Initialize with filename WITHOUT extension
        _filename = State(initialValue: recording.fileNameWithoutExtension)
    }
    
    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(.secondary)
            
            TextField("Filename", text: $filename, onCommit: {
                // Check if name actually changed
                if filename != recording.fileNameWithoutExtension {
                    // Logic: The audioRecorder.renameRecording method handles appending the extension
                    // if it is missing. We are passing just the name here, so it will append extension.
                    // This effectively prevents extension modification by the user since they only edit the name part.
                    audioRecorder.renameRecording(recording, newName: filename)
                }
            })
            .textFieldStyle(.plain)
            
            Spacer()
            
            Text(recording.fileURL.pathExtension)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}