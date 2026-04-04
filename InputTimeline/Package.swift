// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InputTimeline",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "InputTimeline", targets: ["InputTimeline"])
    ],
    targets: [
        .executableTarget(
            name: "InputTimeline",
            path: "Sources/InputTimeline"
        )
    ]
)
