// swift-tools-version:5.9
// Code shared by the Aperture operator apps (macOS in apps/macos, iOS in apps/ios).
// ApertureKit: contract models (mirror of src/aperture/api/contract.py), API client, headline logic.
// Foundation only. ApertureDesign: palette, number formatting and small animated SwiftUI pieces.
import PackageDescription

let package = Package(
    name: "ApertureShared",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ApertureKit", targets: ["ApertureKit"]),
        .library(name: "ApertureDesign", targets: ["ApertureDesign"]),
    ],
    targets: [
        .target(name: "ApertureKit"),
        .target(name: "ApertureDesign"),
        .testTarget(name: "ApertureKitTests", dependencies: ["ApertureKit"]),
        .testTarget(name: "ApertureDesignTests", dependencies: ["ApertureDesign"]),
    ]
)
