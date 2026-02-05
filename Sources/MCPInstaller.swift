import Foundation

enum MCPInstaller {
    /// Get the path to this executable
    private static var executablePath: String {
        // When running inside .app bundle: Pochi.app/Contents/MacOS/Pochi
        // When running from SPM build: .build/release/Pochi
        return CommandLine.arguments[0]
    }

    /// Print an eval-able command for Claude Code installation
    /// Usage: eval $(/Applications/Pochi.app/Contents/MacOS/Pochi --mcp-install)
    static func printInstallCommand() {
        let path = executablePath
        // Output a claude mcp add command
        print("claude mcp add pochi \"\(path)\" --args \"--mcp\"")
    }

    /// Print MCP configuration JSON for Claude Desktop or other MCP clients
    /// Usage: Pochi --mcp-config
    static func printConfig() {
        let path = executablePath
        let config = """
        {
          "mcpServers": {
            "pochi": {
              "command": "\(path)",
              "args": ["--mcp"]
            }
          }
        }
        """
        print(config)
    }
}
