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
            name: "PrivateTouchBar",
            path: "Sources/PrivateTouchBar",
            // Swift 5 language mode just for this target: PrivateTouchBar.swift is an unmodified
            // copy of TokenBar's file (which itself targets Swift 5 mode), and its static mutable
            // state for the method-swizzling hooks doesn't pass Swift 6's strict concurrency
            // checking. Scoped here rather than dropping the whole package to Swift 5 mode.
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .target(
            name: "TouchBarKit",
            dependencies: ["MetricsCore"],
            path: "Sources/TouchBarKit",
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .target(
            name: "AppMain",
            dependencies: ["PrivateTouchBar", "TouchBarKit"],
            path: "Sources/AppMain",
            // Same reason as PrivateTouchBar's own exemption: this target assigns
            // PrivateTouchBar.onExternalCollapse, an unchecked static var by design (it's a
            // callback hook into a method-swizzled private API, not app state), and Swift 6 mode
            // flags that cross-module regardless of the declaring module's own language mode.
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .executableTarget(
            name: "TouchVitals",
            dependencies: ["Modules", "MetricsCore", "TouchBarKit", "PrivateTouchBar", "AppMain"],
            path: "Apps/TouchVitals",
            linkerSettings: [.linkedFramework("AppKit")]
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
