// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "open-chat",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "open-chat",
            targets: ["open-chat"]
        )
    ],
    dependencies: [
        // Dependencies can be added here as needed.
        // Example: Markdown rendering, networking utilities, etc.
    ],
    targets: [
        .target(
            name: "open-chat",
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
