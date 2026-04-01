// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceHub",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoiceHub", targets: ["VoiceToolsApp"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceToolsApp",
            path: "Sources/VoiceToolsApp"
        )
    ]
)
