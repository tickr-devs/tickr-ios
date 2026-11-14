// swift-tools-version:6.2
// Code shared by the Aperture operator apps (macOS in apps/macos, iOS in apps/ios).
// ApertureKit: contract models (mirror of src/aperture/api/contract.py), API client, headline logic
// and the dependency container (Factory). ApertureDesign: palette, tokens, formatting and small
// animated SwiftUI pieces. Swift 6 language mode (strict concurrency), the latest OS releases only.
import PackageDescription

let package = Package(
  name: "ApertureShared",
  // Text a person reads is English in code (each target's L10n.swift) and translated in the
  // target's Resources/Localizable.xcstrings.
  defaultLocalization: "en",
  platforms: [.macOS(.v26), .iOS(.v26)],
  products: [
    .library(name: "ApertureKit", targets: ["ApertureKit"]),
    .library(name: "ApertureDesign", targets: ["ApertureDesign"]),
  ],
  dependencies: [
    // Dependency injection (hmlongco/Factory): services are registered on Container and resolved
    // with @Injected; ApertureKit re-exports FactoryKit to the apps (Dependencies.swift). Pinned
    // to one release: an update is a reviewed change of this line.
    .package(url: "https://github.com/hmlongco/Factory.git", exact: "3.5.3"),
  ],
  targets: [
    .target(
      name: "ApertureKit",
      dependencies: [.product(name: "FactoryKit", package: "Factory")],
      resources: [.process("Resources")]),
    .target(name: "ApertureDesign"),
    // Tests take FactoryTesting (the .container trait), never FactoryKit itself: a second copy of
    // FactoryKit in the test target would give two sets of factories.
    .testTarget(
      name: "ApertureKitTests",
      dependencies: ["ApertureKit", .product(name: "FactoryTesting", package: "Factory")]),
    .testTarget(name: "ApertureDesignTests", dependencies: ["ApertureDesign"]),
  ],
  swiftLanguageModes: [.v6]
)
