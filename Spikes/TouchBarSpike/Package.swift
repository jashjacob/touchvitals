// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TouchBarSpike",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TouchBarSpike",
            path: "Sources/TouchBarSpike",
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)
