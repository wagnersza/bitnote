// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Bitnote",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Bitnote",
            dependencies: ["MeetingDetector", "BitnoteCore"],
            path: "Sources/Bitnote",
            exclude: ["Info.plist"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .target(
            name: "BitnoteCore",
            dependencies: ["MeetingDetector"],
            path: "Sources/BitnoteCore"
        ),
        .target(
            name: "MeetingDetector",
            path: "Sources/MeetingDetector"
        ),
        .testTarget(
            name: "BitnoteTests",
            dependencies: ["MeetingDetector", "BitnoteCore"],
            path: "Tests/BitnoteTests"
        )
    ]
)
