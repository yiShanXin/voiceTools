// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceTools",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoiceTools", targets: ["VoiceToolsApp"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceToolsApp",
            path: "Sources/VoiceToolsApp"
        )
    ]
)
