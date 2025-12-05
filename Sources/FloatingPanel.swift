import SwiftUI
import AppKit

class FloatingPanel: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        // Initialize with a default style mask, we will configure it further below
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .hudWindow, .utilityWindow], backing: backing, defer: flag)
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Create a transparent, borderless window look
        self.styleMask = [.nonactivatingPanel, .hudWindow, .utilityWindow]
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.hasShadow = true
        
        // Position it initially (Top Right, below menu bar)
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            // screenRect.maxY is the bottom of the menu bar
            // x: Right side with some padding (220 width approx), y: Just below menu bar
            let newOrigin = NSPoint(x: screenRect.maxX - 220, y: screenRect.maxY - 70)
            self.setFrameOrigin(newOrigin)
        }
    }
    
    override var canBecomeKey: Bool {
        return false // Don't steal focus
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

struct RecorderStatusView: View {
    @ObservedObject var recorder: AudioRecorder
    
    var body: some View {
        HStack(spacing: 12) {
            // Recording Indicator & Level Meter
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 4, height: 16)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green)
                    .frame(width: 4, height: 16 * CGFloat(recorder.audioLevel))
                    .animation(.easeOut(duration: 0.1), value: recorder.audioLevel)
            }
            
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(recorder.isRecording ? 1.0 : 0.3)
                .animation(recorder.isRecording ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: recorder.isRecording)
            
            Text(formatTime(recorder.recordingTime))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
            
            Button(action: {
                recorder.stopRecording()
            }) {
                Image(systemName: "stop.fill")
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
