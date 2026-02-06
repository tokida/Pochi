// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pochi",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "Pochi",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
