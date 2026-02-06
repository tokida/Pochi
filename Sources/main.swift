import Foundation
import AppKit

let arguments = CommandLine.arguments

// --mcp: Run as MCP server (stdio transport)
if arguments.contains("--mcp") {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        do {
            try await PochiMCPServer.run()
        } catch {
            fputs("MCP Server error: \(error)\n", stderr)
            exit(1)
        }
        semaphore.signal()
    }
    semaphore.wait()
    exit(0)
}

// --mcp-install: Print eval-able install command for Claude Code
if arguments.contains("--mcp-install") {
    MCPInstaller.printInstallCommand()
    exit(0)
}

// --mcp-config: Print MCP configuration JSON
if arguments.contains("--mcp-config") {
    MCPInstaller.printConfig()
    exit(0)
}

// Normal GUI mode
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
