import LocalAuthentication

/// Face ID (or the device passcode) before a command that cancels orders or closes positions.
enum Biometrics {
  enum Outcome: Equatable {
    case confirmed
    case declined
    /// The phone has no passcode, so the owner cannot be proven; the command is refused.
    case unavailable(String)
  }

  static func confirm(_ reason: String) async -> Outcome {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
      return .unavailable(error?.localizedDescription ?? "Face ID and passcode are not available")
    }
    do {
      return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        ? .confirmed : .declined
    } catch {
      return .declined
    }
  }
}
