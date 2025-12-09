import Foundation

class LaunchManager: ObservableObject {
    @Published var isLaunchAtLoginEnabled: Bool = false
    
    private var plistURL: URL? {
        guard let home = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        return home.appendingPathComponent("LaunchAgents").appendingPathComponent("com.pochi.autorecord.plist")
    }
    
    init() {
        checkStatus()
    }
    
    func checkStatus() {
        guard let url = plistURL else { return }
        isLaunchAtLoginEnabled = FileManager.default.fileExists(atPath: url.path)
    }
    
    func toggleLaunchAtLogin(enabled: Bool) {
        guard let url = plistURL else { return }
        
        if enabled {
            guard let appPath = Bundle.main.executablePath else {
                print("Could not find app executable path")
                return
            }
            
            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.pochi.autorecord</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(appPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>KeepAlive</key>
                <false/>
            </dict>
            </plist>
            """
            
            do {
                let directory = url.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                }
                try plistContent.write(to: url, atomically: true, encoding: .utf8)
                isLaunchAtLoginEnabled = true
                print("Launch at login enabled. Plist written to: \(url.path)")
            } catch {
                print("Failed to enable launch at login: \(error)")
            }
        } else {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                isLaunchAtLoginEnabled = false
                print("Launch at login disabled.")
            } catch {
                print("Failed to disable launch at login: \(error)")
            }
        }
    }
}
