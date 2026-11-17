// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TouchVitals",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TouchVitals", targets: ["TouchVitals"]),
    ],
    targets: [
        .target(
            name: "SystemKit",
            path: "Sources/SystemKit"
        ),
        .target(
            name: "Diagnostics",
            path: "Sources/Diagnostics"
        ),
        .target(
            name: "MetricsCore",
            dependencies: ["SystemKit"],
            path: "Sources/MetricsCore"
        ),
        .target(
            name: "Modules",
            dependencies: ["SystemKit", "MetricsCore", "Diagnostics"],
            path: "Sources/Modules"
        ),
        .executableTarget(
            name: "TouchVitals",
            dependencies: ["Modules", "MetricsCore"],
            path: "Apps/TouchVitals"
        ),
    ]
)
