// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "NotchLookup",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1"),
    ],
    targets: [
        // Core business logic — testable library (no AppKit/UI imports).
        .target(
            name: "NotchLookupCore",
            path: "Sources/NotchLookupCore"
        ),

        // Main app executable — depends on Core + HotKey.
        .executableTarget(
            name: "NotchLookup",
            dependencies: [
                "NotchLookupCore",
                .product(name: "HotKey", package: "HotKey"),
            ],
            path: "Sources/NotchLookup"
        ),

        // Unit tests for Core business logic.
        .testTarget(
            name: "NotchLookupTests",
            dependencies: ["NotchLookupCore"],
            path: "Tests/NotchLookupTests"
        ),
    ]
)
