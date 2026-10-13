// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeetingMute",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: the app registry, matching rules and dismiss policy. No AppKit.
        .target(
            name: "MeetingMuteCore",
            path: "Sources/MeetingMuteCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "MeetingMute",
            dependencies: ["MeetingMuteCore"],
            path: "Sources/MeetingMute",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // `swift run CoreChecks`: checks for MeetingMuteCore that run with only the
        // Command Line Tools (XCTest needs the full Xcode).
        .executableTarget(
            name: "CoreChecks",
            dependencies: ["MeetingMuteCore"],
            path: "Sources/CoreChecks",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
