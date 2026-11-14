// swift-tools-version:5.9
// Aperture operator app for macOS. Contract models, API client and design pieces come from the
// shared package in apps/shared (also used by the iOS app in apps/ios).
import PackageDescription

let package = Package(
    name: "ApertureApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ApertureMac", targets: ["ApertureMac"]),
    ],
    dependencies: [
        .package(name: "ApertureShared", path: "../shared"),
    ],
    targets: [
        .target(
            name: "ApertureUI",
            dependencies: [.product(name: "ApertureKit", package: "ApertureShared")]),
        .executableTarget(
            name: "ApertureMac",
            dependencies: ["ApertureUI", .product(name: "ApertureKit", package: "ApertureShared")]),
    ]
)
