// swift-tools-version:5.9
import PackageDescription

// MARK: - NimbusKit
//
// NimbusKit is the platform-agnostic core of Nimbus VPN. It contains the domain
// models, the modular protocol/configuration system, the config-URI parsers,
// persistence, and the service layer (tunnel control, statistics, logging,
// servers, cloud sync, DNS, security). It depends only on `Foundation` so it
// compiles and its tests run on Linux CI as well as on Apple platforms — the
// SwiftUI app and the Network Extension (which require Xcode) live outside the
// package and depend on it.
//
// Anything that requires an Apple-only framework (CryptoKit, Network,
// NetworkExtension, LocalAuthentication) is expressed here as a protocol and
// gated behind `#if canImport(...)`, with the concrete Apple implementation
// living in the app/extension targets. This keeps the core testable everywhere.
//
// The package pins swift-tools 5.9, so it builds in the Swift 5 language mode by
// default on any 5.9+/6.x toolchain — no strict-concurrency build failures.

let package = Package(
    name: "NimbusKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "NimbusKit", targets: ["NimbusKit"])
    ],
    targets: [
        .target(
            name: "NimbusKit",
            path: "Sources/NimbusKit"
        ),
        .testTarget(
            name: "NimbusKitTests",
            dependencies: ["NimbusKit"],
            path: "Tests/NimbusKitTests"
        )
    ]
)
