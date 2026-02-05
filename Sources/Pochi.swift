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

    // HotKey References
    var hotKeyRef: EventHotKeyRef?
    var popoverHotKeyRef: EventHotKeyRef?

    // Fallback positioning window for when status item is absorbed into mic menu
    var anchorWindow: NSWindow?
    
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
        registerHotKey() // Cmd+Opt+R: record, Cmd+Opt+P: popover
    }
    
    func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        // Install handler that dispatches based on hotkey ID
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(theEvent,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hotKeyID)

            if let delegate = NSApplication.shared.delegate as? AppDelegate {
                switch hotKeyID.id {
                case 1:
                    delegate.toggleRecording()
                case 2:
                    delegate.togglePopover(nil)
                default:
                    break
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)

        let modifiers = cmdKey | optionKey

        // HotKey 1: Command + Option + R -> Toggle Recording
        let recordHotKeyID = EventHotKeyID(signature: OSType(0x52454344), id: 1) // 'RECD'
        let kVK_ANSI_R = 0x0F
        RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(modifiers), recordHotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        // HotKey 2: Command + Option + P -> Toggle Popover
        let popoverHotKeyID = EventHotKeyID(signature: OSType(0x504F5055), id: 2) // 'POPU'
        let kVK_ANSI_P = 0x23
        RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(modifiers), popoverHotKeyID, GetApplicationEventTarget(), 0, &popoverHotKeyRef)
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
        if popover.isShown {
            popover.performClose(sender)
            cleanupAnchorWindow()
            return
        }

        audioRecorder.fetchRecordings() // Refresh list before showing

        // Try to show anchored to the status item button
        if let button = statusItem.button, button.window != nil, button.window?.isVisible == true {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        } else {
            // Fallback: status item may be absorbed into macOS microphone menu.
            // Show using a temporary anchor window near the menu bar.
            showPopoverWithFallbackAnchor()
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showPopoverWithFallbackAnchor() {
        cleanupAnchorWindow()

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        // Position anchor at top-right area (near where status items live)
        let menuBarHeight = screenFrame.height - visibleFrame.height - visibleFrame.origin.y
        let anchorX = screenFrame.maxX - 200
        let anchorY = screenFrame.maxY - menuBarHeight

        let window = NSWindow(
            contentRect: NSRect(x: anchorX, y: anchorY, width: 1, height: 1),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        window.orderFront(nil)
        self.anchorWindow = window

        if let contentView = window.contentView {
            popover.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        }
    }

    private func cleanupAnchorWindow() {
        anchorWindow?.orderOut(nil)
        anchorWindow = nil
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