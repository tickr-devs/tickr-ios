import Testing
@testable import TickrDesign

/// The one environment badge of both apps: the bot's status value picks its tone and edge.
@Suite struct EnvironmentBadgeTests {
  @Test(arguments: [("sandbox", EnvironmentBadge.Kind.sandbox), ("production", .production), ("demo", .demo)])
  func knownEnvironments(raw: String, kind: EnvironmentBadge.Kind) {
    #expect(EnvironmentBadge.Kind(raw: raw) == kind)
  }

  /// Sandbox amber, Production red, the demo day violet and dashed.
  @Test func tonesAndEdges() {
    #expect(EnvironmentBadge.Kind.sandbox.tone == .warning)
    #expect(EnvironmentBadge.Kind.production.tone == .loss)
    #expect(EnvironmentBadge.Kind.demo.tone == .highlight)
    #expect(EnvironmentBadge.Kind.demo.dashed)
    #expect(!EnvironmentBadge.Kind.sandbox.dashed)
    #expect(!EnvironmentBadge.Kind.production.dashed)
  }

  /// A value newer than the app, or in another case, is a plain fact, never a known environment.
  @Test(arguments: ["staging", "Sandbox", ""])
  func unknownEnvironmentIsNeutral(raw: String) {
    let kind = EnvironmentBadge.Kind(raw: raw)
    #expect(kind == .unknown)
    #expect(kind.tone == .neutral)
    #expect(!kind.dashed)
  }

  /// Every screen gets the same badge for the same value.
  @Test func badgeTakesItsKindFromTheRawValue() {
    let sandbox = EnvironmentBadge("Sandbox", raw: "sandbox", accessibilityLabel: "Environment: Sandbox")
    #expect(sandbox.kind == .sandbox)
    #expect(sandbox.label == "Environment: Sandbox")
    #expect(EnvironmentBadge("Production", raw: "production", accessibilityLabel: "").kind == .production)
  }

  /// Production never shares Sandbox's colour.
  @Test func environmentsHaveDistinctTones() {
    let known = EnvironmentBadge.Kind.allCases
    #expect(Set(known.map(\.tone)).count == known.count)
  }
}
