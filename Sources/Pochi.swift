import SwiftUI
import AppKit
import Combine
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var audioRecorder = AudioRecorder()
    var settingsManager = SettingsManager()
    var popover: NSPopover!
    var cancellables = Set<AnyCancellable>()
    
    // HotKey Reference
    var hotKeyRef: EventHotKeyRef?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Set a default title first to ensure visibility even if image fails
            button.title = "REC"
            button.imagePosition = .imageLeft
            // Try to load the image
            if let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Record") {
                button.image = image
                button.title = "" // Clear title if image loads successfully
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        setupPopover()
        setupBindings()
        registerHotKey() // Command + Option + R
    }
    
    func registerHotKey() {
        // Register global hotkey: Command + Option + R
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        // Install handler
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            if let delegate = NSApplication.shared.delegate as? AppDelegate {
                delegate.toggleRecording()
            }
            return noErr
        }, 1, &eventType, nil, nil)
        
        // Define HotKey ID
        let hotKeyID = EventHotKeyID(signature: OSType(0x52454344), id: 1) // 'RECD', 1
        
        // Modifiers: cmdKey + optionKey
        let modifiers = cmdKey | optionKey
        
        // KeyCode for 'R' is 15
        let kVK_ANSI_R = 0x0F
        
        RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        // Pass both dependencies
        popover.contentViewController = NSHostingController(rootView: RecordingListView(audioRecorder: audioRecorder, settingsManager: settingsManager))
        self.popover = popover
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                audioRecorder.fetchRecordings() // Refresh list before showing
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Bring to front
                NSApplication.shared.activate(ignoringOtherApps: true)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    func setupBindings() {
        audioRecorder.$isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] isRecording in
                self?.updateUI(isRecording: isRecording)
            }
            .store(in: &cancellables)
            
        audioRecorder.$audioLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.updateIcon(level: level)
            }
            .store(in: &cancellables)
            
        // Timer update binding
        audioRecorder.$recordingTime
            .receive(on: RunLoop.main)
            .sink { [weak self] time in
                self?.updateTimeDisplay(time: time)
            }
            .store(in: &cancellables)
            
        // Settings update binding
        settingsManager.$showTimerInMenuBar
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                // Force update display
                if let self = self {
                    self.updateTimeDisplay(time: self.audioRecorder.recordingTime)
                }
            }
            .store(in: &cancellables)
    }
    
    func updateTimeDisplay(time: TimeInterval) {
        guard let button = statusItem.button else { return }
        
        if audioRecorder.isRecording && settingsManager.showTimerInMenuBar {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            button.title = String(format: " %02d:%02d", minutes, seconds)
            // Use monospaced digit font for stability
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        } else {
            button.title = ""
        }
    }
    
    func updateIcon(level: Float) {
        guard audioRecorder.isRecording, let button = statusItem.button else { return }
        
        // Create a dynamic image based on level
        let size = NSSize(width: 22, height: 22)
        let img = NSImage(size: size)
        
        img.lockFocus()
        
        // Draw context
        if let ctx = NSGraphicsContext.current {
            ctx.imageInterpolation = .high
            
            // Base radius (minimum size) + Dynamic expansion
            // Level is 0.0 to 1.0
            // Min radius: 3.0 (diameter 6)
            // Max radius: 8.0 (diameter 16)
            let maxRadius: CGFloat = 8.0
            let minRadius: CGFloat = 3.0
            let currentRadius = minRadius + (CGFloat(level) * (maxRadius - minRadius))
            
            let rect = NSRect(x: (size.width / 2) - currentRadius,
                              y: (size.height / 2) - currentRadius,
                              width: currentRadius * 2,
                              height: currentRadius * 2)
            
            NSColor.systemRed.setFill()
            let path = NSBezierPath(ovalIn: rect)
            path.fill()
        }
        
        img.unlockFocus()
        img.isTemplate = false // Ensure color is preserved (Red)
        
        button.image = img
        // Clear tint color to allow original image color (Red) to show
        button.contentTintColor = nil 
    }
    
    func updateUI(isRecording: Bool) {
        guard let button = statusItem.button else { return }
        
        if isRecording {
            // Initial update
            updateTimeDisplay(time: 0)
        } else {
            // Reset icon and title when stopped
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Record")
            button.contentTintColor = .labelColor
            button.title = ""
        }
    }
    
    @objc func toggleRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
        } else {
            audioRecorder.startRecording()
        }
    }
}