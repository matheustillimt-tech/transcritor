// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Transcritor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Transcritor",
            path: "Sources/Transcritor"
        )
    ]
)
