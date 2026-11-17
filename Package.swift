// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TouchVitals",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TouchVitals", targets: ["TouchVitals"]),
    ],
    dependencies: [
        // Still required even though Swift Testing ships in the toolchain: without it, the test
        // target fails with "unable to resolve module dependency: '_TestingInternals'" on a
        // Command Line Tools-only install (no full Xcode) — same issue vitals' own Package.swift
        // documents. The deprecation warning this triggers is expected and safe to ignore here.
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0"),
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
        .target(
            name: "TouchBarKit",
            dependencies: ["MetricsCore"],
            path: "Sources/TouchBarKit"
        ),
        .executableTarget(
            name: "TouchVitals",
            dependencies: ["Modules", "MetricsCore"],
            path: "Apps/TouchVitals"
        ),
        .testTarget(
            name: "TouchBarKitTests",
            dependencies: [
                "TouchBarKit",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/TouchBarKitTests"
        ),
    ]
)
