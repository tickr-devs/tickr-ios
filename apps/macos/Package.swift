// swift-tools-version:6.2
// Aperture operator app for macOS, buildable without Xcode (`swift build`, scripts/make-app.sh).
// In Xcode open Aperture.xcworkspace at the repository root instead: ApertureMac.xcodeproj builds
// the same sources (folder Aperture/) as a signed app. Contract models, API client and design
// pieces come from the shared package in apps/shared (also used by the iOS app in apps/ios).
import PackageDescription

let package = Package(
  name: "ApertureApp",
  // Text a person reads is English in Aperture/L10n.swift, translated in Aperture/Localizable.xcstrings.
  defaultLocalization: "en",
  platforms: [.macOS(.v26)],
  products: [
    .executable(name: "ApertureMac", targets: ["ApertureMac"]),
  ],
  dependencies: [
    .package(name: "ApertureShared", path: "../shared"),
    // Only for the tests' FactoryTesting (the .container trait); the same pinned release as
    // apps/shared/Package.swift, which the app takes FactoryKit from.
    .package(url: "https://github.com/hmlongco/Factory.git", exact: "3.5.3"),
  ],
  targets: [
    .executableTarget(
      name: "ApertureMac",
      dependencies: [
        .product(name: "ApertureKit", package: "ApertureShared"),
        .product(name: "ApertureDesign", package: "ApertureShared"),
      ],
      path: "Aperture",
      // The app icon is compiled by Xcode (actool); a `swift build` app has the generic icon.
      exclude: ["AppIcon.icon"],
      resources: [.process("Localizable.xcstrings")],
      // The same language settings as the Xcode project (SWIFT_APPROACHABLE_CONCURRENCY and
      // SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY), so both builds compile alike.
      swiftSettings: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("MemberImportVisibility"),
      ]),
    // Swift Testing tests of the screens' logic (zoom, marks, levels, scales), run by `swift test`.
    .testTarget(
      name: "ApertureMacTests",
      dependencies: ["ApertureMac", .product(name: "FactoryTesting", package: "Factory")],
      path: "Tests",
      swiftSettings: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("MemberImportVisibility"),
      ]),
  ],
  // Swift 6 language mode: strict concurrency, as in the Xcode project (SWIFT_VERSION = 6.0).
  swiftLanguageModes: [.v6]
)
