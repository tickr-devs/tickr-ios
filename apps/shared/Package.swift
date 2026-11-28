// swift-tools-version:6.2
// Code shared by the Tickr operator apps (macOS in apps/macos, iOS in apps/ios).
// TickrKit: contract models (mirror of src/tickr/api/contract.py), API client, headline logic
// and the dependency container (Factory). TickrDesign: palette, tokens, formatting and small
// animated SwiftUI pieces, including the one look of each shared meaning of a TickrKit model (a
// stop's state, a headline's severity, a verdict, an exit), so it builds on TickrKit. Swift 6 language mode (strict concurrency), the latest OS releases only.
import PackageDescription

let package = Package(
  name: "TickrShared",
  // Text a person reads is English in code (each target's L10n.swift) and translated in the
  // target's Resources/Localizable.xcstrings.
  defaultLocalization: "en",
  platforms: [.macOS(.v26), .iOS(.v26)],
  products: [
    .library(name: "TickrKit", targets: ["TickrKit"]),
    .library(name: "TickrDesign", targets: ["TickrDesign"]),
  ],
  dependencies: [
    // Dependency injection (hmlongco/Factory): services are registered on Container and resolved
    // with @Injected; TickrKit re-exports FactoryKit to the apps (Dependencies.swift). Pinned
    // to one release: an update is a reviewed change of this line.
    .package(url: "https://github.com/hmlongco/Factory.git", exact: "3.5.3"),
  ],
  targets: [
    .target(
      name: "TickrKit",
      dependencies: [.product(name: "FactoryKit", package: "Factory")],
      resources: [.process("Resources")]),
    // Resources: the wordmark's font (Manrope 700 cut to "ickr", SIL OFL, Manrope-OFL.txt).
    .target(name: "TickrDesign", dependencies: ["TickrKit"], resources: [.process("Resources")]),
    // Tests take FactoryTesting (the .container trait), never FactoryKit itself: a second copy of
    // FactoryKit in the test target would give two sets of factories.
    .testTarget(
      name: "TickrKitTests",
      dependencies: ["TickrKit", .product(name: "FactoryTesting", package: "Factory")]),
    .testTarget(name: "TickrDesignTests", dependencies: ["TickrDesign", "TickrKit"]),
  ],
  swiftLanguageModes: [.v6]
)
