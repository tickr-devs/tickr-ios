// swift-tools-version:5.9
// Aperture operator app. ApertureKit (contract models + API client) and ApertureUI (SwiftUI views)
// are platform-neutral so an iOS target can reuse them; ApertureMac is the macOS app shell.
import PackageDescription

let package = Package(
    name: "ApertureApp",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "ApertureKit", targets: ["ApertureKit"]),
        .library(name: "ApertureUI", targets: ["ApertureUI"]),
        .executable(name: "ApertureMac", targets: ["ApertureMac"]),
    ],
    targets: [
        .target(name: "ApertureKit"),
        .target(name: "ApertureUI", dependencies: ["ApertureKit"]),
        .executableTarget(name: "ApertureMac", dependencies: ["ApertureKit", "ApertureUI"]),
        .testTarget(name: "ApertureKitTests", dependencies: ["ApertureKit"]),
    ]
)
