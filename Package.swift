// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ArtemisTracker",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ArtemisTracker",
            path: "Sources/ArtemisTracker",
            exclude: ["Info.plist"]
        )
    ]
)
