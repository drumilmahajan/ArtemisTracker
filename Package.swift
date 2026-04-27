// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Galileo",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Galileo",
            path: "Sources/Galileo",
            exclude: ["Info.plist"]
        )
    ]
)
