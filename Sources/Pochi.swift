import SwiftUI
import AppKit
import Combine
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var audioRecorder = AudioRecorder()
    var floatingPanel: FloatingPanel!
    var cancellables = Set<AnyCancellable>()
    
    // HotKey Reference
    var hotKeyRef: EventHotKeyRef?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Set a default title first to ensure visibility even if image fails
            button.title = "REC"
            // Try to load the image
            if let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Record") {
                button.image = image
                button.title = "" // Clear title if image loads successfully
            }
        }
        
        setupMenu()
        setupFloatingPanel()
        setupBindings()
        registerHotKey() // Command + Option + R
    }
    
    func registerHotKey() {
        // Register global hotkey: Command + Option + R
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        // Install handler
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            // Unsafe pointer cast to get AppDelegate instance if needed, but here we use a global singleton approach or closure capture if possible.
            // Since C-function pointer context is tricky in Swift without a global/static, 
            // we will use the NotificationCenter to broadcast the hotkey event or access the shared delegate if possible.
            // For simplicity in this script, we'll forward to the NSApp delegate.
            
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
    
    func setupMenu() {
        let menu = NSMenu()
        
        let recordItem = NSMenuItem(title: "Start Recording", action: #selector(toggleRecording), keyEquivalent: "r")
        // Bind title to recording state dynamically if possible, but for now we use updateMenu
        recordItem.tag = 1 
        menu.addItem(recordItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Open Recordings Folder", action: #selector(openFolder), keyEquivalent: "o"))
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    func setupFloatingPanel() {
        let contentView = RecorderStatusView(recorder: audioRecorder)
        let hostingController = NSHostingController(rootView: contentView)
        
        floatingPanel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 50), // Size will be adjusted by SwiftUI content
            backing: .buffered,
            defer: false
        )
        floatingPanel.contentViewController = hostingController
        
        // Auto-resize panel to fit SwiftUI content
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        // Initial layout pass might be needed
        floatingPanel.layoutIfNeeded()
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
        guard let button = statusItem.button, let menu = statusItem.menu else { return }
        
        // Update Menu Item Text
        if let recordItem = menu.item(withTag: 1) {
            recordItem.title = isRecording ? "Stop Recording" : "Start Recording"
        }
        
        // Show/Hide Floating Panel
        if isRecording {
            floatingPanel.orderFront(nil)
        } else {
            floatingPanel.orderOut(nil)
            // Reset icon when stopped
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Record")
            button.contentTintColor = .labelColor
        }
    }
    
    @objc func toggleRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
        } else {
            audioRecorder.startRecording()
        }
    }
    
    @objc func openFolder() {
        let fileManager = FileManager.default
        if let musicDirectory = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first {
            let saveUrl = musicDirectory.appendingPathComponent("Pochi")
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: saveUrl.path)
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
