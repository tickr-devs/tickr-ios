#if canImport(ActivityKit) && os(iOS)
import ActivityKit

// The Live Activity's attributes as ActivityKit knows them (LiveActivity.swift has the type): on
// iOS only, where the app reports the activity's tokens and the widget extension draws it.
extension TickrActivityAttributes: ActivityAttributes {}
#endif
