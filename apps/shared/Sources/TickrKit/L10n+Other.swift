import Foundation

/// What the apps say for a code this app does not know (a bot of another release), instead of the code.
extension L10n {
  /// Why a symbol stopped, for a cause code this app does not know.
  static var reasonOther: LocalizedStringResource {
    LocalizedStringResource("kit.reasonOther", defaultValue: "Other reason (update the app to see it)",
      bundle: bundle)
  }
}
