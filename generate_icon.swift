import Cocoa

let size = NSSize(width: 1024, height: 1024)
let img = NSImage(size: size)

img.lockFocus()

// Context
let ctx = NSGraphicsContext.current?.cgContext

// 1. Background (Rounded Rect - Dark Gray)
let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: rect, xRadius: 180, yRadius: 180)
NSColor(white: 0.15, alpha: 1.0).setFill()
path.fill()

// 2. Red Circle
let circleRect = NSRect(x: 212, y: 212, width: 600, height: 600)
NSColor.systemRed.setFill()
NSBezierPath(ovalIn: circleRect).fill()

// 3. White Mic (Simple shapes)
NSColor.white.setFill()
// Body
let micRect = NSRect(x: 512 - 60, y: 512 - 150, width: 120, height: 280)
NSBezierPath(roundedRect: micRect, xRadius: 60, yRadius: 60).fill()

// Base stand
let standRect = NSRect(x: 512 - 10, y: 512 - 250, width: 20, height: 100)
NSBezierPath(rect: standRect).fill()

// Foot
let footRect = NSRect(x: 512 - 80, y: 512 - 250, width: 160, height: 20)
NSBezierPath(roundedRect: footRect, xRadius: 10, yRadius: 10).fill()


img.unlockFocus()

// Save to PNG
if let tiffData = img.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    let url = URL(fileURLWithPath: "AppIcon.png")
    try? pngData.write(to: url)
    print("AppIcon.png created successfully")
}
