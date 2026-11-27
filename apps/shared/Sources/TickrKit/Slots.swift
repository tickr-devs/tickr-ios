import Foundation

/// The position slots as the engine counts them against `max_open_positions`
/// (`risk/admission.py` `open_positions`, `Engine.open_trade`): an open position and an own entry
/// order still working each take one, so an entry waiting for its fill is not a free slot.
public enum Slots {
  /// Slots taken: the open positions and the working entries.
  public static func used(_ status: StatusV1) -> Int {
    status.positions.count + status.workingEntries.count
  }

  /// Slots left under `limit`, none below zero.
  public static func free(_ status: StatusV1, limit: Int) -> Int {
    max(0, limit - used(status))
  }

  /// `text` with how many slots working entries hold, while any do: "1 of 3 slots free · 1 pending".
  public static func withPending(_ text: String, _ status: StatusV1) -> String {
    let pending = status.workingEntries.count
    guard pending > 0 else { return text }
    let words = String(localized: pending == 1 ? L10n.slotsPendingOne : L10n.slotsPending(pending))
    return String(localized: L10n.slotsWithPending(text, words))
  }
}
