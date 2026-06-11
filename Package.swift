// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KindleDrop",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "KindleDrop",
            path: "Sources/KindleDrop",
            exclude: ["Resources/Info.plist", "Resources/AppIcon.icns"]
        )
    ]
)
