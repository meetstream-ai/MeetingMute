// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeetingMute",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MeetingMute",
            path: "Sources/MeetingMute",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
