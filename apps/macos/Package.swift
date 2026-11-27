// swift-tools-version:6.2
// Tickr operator app for macOS, buildable without Xcode (`swift build`, scripts/make-app.sh).
// In Xcode open Tickr.xcworkspace at the repository root instead: TickrMac.xcodeproj builds
// the same sources (folder Tickr/) as a signed app. Contract models, API client and design
// pieces come from the shared package in apps/shared (also used by the iOS app in apps/ios).
//
// The screens (folder Tickr/) are the library TickrScreens, which the iOS app also takes: an iPad
// or an unfolded iPhone in regular width shows these same screens (mockup v156, board
// IPadLandscape). What only a Mac has (the menu bar, windows, notifications of the bot's
// alerts) is inside `#if os(macOS)`. The executable TickrMac (folder Launch/) only starts them.
import PackageDescription

let package = Package(
  name: "TickrApp",
  // Text a person reads is English in Tickr/L10n.swift, translated in Tickr/Localizable.xcstrings.
  defaultLocalization: "en",
  platforms: [.macOS(.v26), .iOS(.v26)],
  products: [
    .executable(name: "TickrMac", targets: ["TickrMac"]),
    .library(name: "TickrScreens", targets: ["TickrScreens"]),
  ],
  dependencies: [
    .package(name: "TickrShared", path: "../shared"),
    // Only for the tests' FactoryTesting (the .container trait); the same pinned release as
    // apps/shared/Package.swift, which the app takes FactoryKit from.
    .package(url: "https://github.com/hmlongco/Factory.git", exact: "3.5.3"),
  ],
  targets: [
    .executableTarget(
      name: "TickrMac",
      dependencies: ["TickrScreens"],
      path: "Launch",
      swiftSettings: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("MemberImportVisibility"),
      ]),
    .target(
      name: "TickrScreens",
      dependencies: [
        .product(name: "TickrKit", package: "TickrShared"),
        .product(name: "TickrDesign", package: "TickrShared"),
      ],
      path: "Tickr",
      // The app icon is compiled by actool (Xcode, or scripts/make-app.sh), not by SwiftPM.
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
      name: "TickrMacTests",
      dependencies: ["TickrScreens", .product(name: "FactoryTesting", package: "Factory")],
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
