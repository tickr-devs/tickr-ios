import Foundation

/// The words of `Slots`, in English with their Spanish translation in Resources/Localizable.xcstrings.
extension L10n {
  /// A count of working entries holding slots: "1 pending", "2 pending".
  static var slotsPendingOne: LocalizedStringResource {
    LocalizedStringResource("kit.slots.pendingOne", defaultValue: "1 pending", bundle: bundle)
  }
  static func slotsPending(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.slots.pending", defaultValue: "\(count) pending", bundle: bundle)
  }
  /// A slots line with its pending count after it.
  static func slotsWithPending(_ text: String, _ pending: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.slots.withPending", defaultValue: "\(text) · \(pending)", bundle: bundle)
  }
}
