import Foundation
import MCP

enum PochiMCPServer {
    static func run() async throws {
        let server = Server(
            name: "Pochi",
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: false)
            )
        )

        let toolHandler = PochiToolHandler()
        let tools = PochiToolHandler.buildTools()

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: tools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            try await toolHandler.handle(params)
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}
