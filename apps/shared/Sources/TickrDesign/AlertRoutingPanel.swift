import SwiftUI
import TickrKit

// The notification settings' content on both apps (GET /alerts, PUT /alerts/routing, backlog
// T14, mockup MacGateAlerts › Notifications): the channels with what the morning check proved,
// then a grid of the alert kinds the owner can switch, one column per channel, then the kinds that
// are always on everywhere. Each app wraps it in its own settings card with `AlertText.title`.

extension AlertChannel {
  /// The channel's full name, its column's short name and its symbol.
  public var title: LocalizedStringResource {
    switch self {
    case .mac: AlertText.macChannel
    case .imessage: AlertText.imessageChannel
    case .push: AlertText.pushChannel
    }
  }

  var column: LocalizedStringResource {
    switch self {
    case .mac: AlertText.macColumn
    case .imessage: AlertText.imessageColumn
    case .push: AlertText.pushColumn
    }
  }

  var note: LocalizedStringResource {
    switch self {
    case .mac: AlertText.macNote
    case .imessage: AlertText.imessageNote
    case .push: AlertText.pushNote
    }
  }

  var symbol: String {
    switch self {
    case .mac: AlertRoutingPanel.macSymbol
    case .imessage: AlertRoutingPanel.imessageSymbol
    case .push: AlertRoutingPanel.pushSymbol
    }
  }
}

extension AlertGroup {
  var title: LocalizedStringResource {
    switch self {
    case .critical: AlertText.critical
    case .trading: AlertText.trading
    case .day: AlertText.day
    case .lab: AlertText.lab
    }
  }
}

extension AlertChannelV1 {
  /// How the channel's row reads: green when the morning check proved it, amber when it failed
  /// there, grey when nothing says yet or it does not exist yet.
  var health: SystemCard.Health {
    if configured { return .good }
    switch cause {
    case .checkFailed: return .attention
    case .preflightUnreadable: return .unknown
    case .noPreflight, .notBuilt, nil: return .idle
    }
  }

  var state: LocalizedStringResource {
    if configured { return AlertText.works }
    switch cause {
    case .noPreflight: return AlertText.noPreflight
    case .preflightUnreadable: return AlertText.preflightUnreadable
    case .checkFailed: return AlertText.checkFailed
    case .notBuilt, nil: return AlertText.notBuilt
    }
  }
}

public struct AlertRoutingPanel: View {
  /// Symbols of the channels, the always-on rows and the note under the grid.
  static let macSymbol = "desktopcomputer"
  static let imessageSymbol = "message.fill"
  static let pushSymbol = "iphone"
  static let lockSymbol = Symbols.gateClosed
  static let feedSymbol = "tray.full"

  let alerts: AlertsV1
  let routing: AlertRouting
  let change: (AlertCell, Bool) -> Void

  /// `change`: send one cell's new value (the app's model calls `AlertRouting.set` with its client).
  public init(_ alerts: AlertsV1, routing: AlertRouting, change: @escaping (AlertCell, Bool) -> Void) {
    self.alerts = alerts
    self.routing = routing
    self.change = change
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      SectionLabel(AlertText.channels)
      ForEach(alerts.channels, id: \.channel) { channel in
        SystemRow(channel.channel.title, symbol: channel.channel.symbol, health: channel.health,
          note: Text(channel.channel.note)) {
          Text(channel.state).foregroundStyle(channel.configured ? Tone.profit.text : Palette.textTertiary)
        }
      }
      if alerts.routingCause != nil {
        InfoCaption(AlertText.routingUnusable, systemImage: Symbols.failure, tone: .warning)
      }
      grid
      if let error = routing.changeError {
        InfoCaption(Text(AlertText.notChanged(error)), systemImage: Symbols.failure, tone: .warning)
      }
      locked
      InfoCaption(AlertText.appliesNext, systemImage: Self.feedSymbol)
    }
  }

  // MARK: the switches

  private var grid: some View {
    Grid(alignment: .leading, horizontalSpacing: Tokens.Space.m, verticalSpacing: Tokens.Space.s) {
      GridRow {
        SectionLabel(AlertText.alerts)
        ForEach(AlertChannel.allCases, id: \.self) { channel in
          Text(channel.column)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(alerts.canChange(channel) ? Palette.textTertiary : Palette.textQuaternary)
            .fixedSize()
            .gridColumnAlignment(.center)
        }
      }
      ForEach(alerts.switchableGroups, id: \.group) { section in
        GridRow {
          Text(section.group.title)
            .font(Tokens.Typography.caption.weight(.semibold))
            .foregroundStyle(Palette.textTertiary)
            .gridCellColumns(AlertChannel.allCases.count + 1)
            .padding(.top, Tokens.Space.xs)
        }
        ForEach(section.kinds, id: \.kind) { kind in
          GridRow {
            Text(AlertText.kind(kind.kind))
              .font(Tokens.Typography.body)
              .foregroundStyle(Palette.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(AlertChannel.allCases, id: \.self) { channel in
              cell(kind, channel)
            }
          }
        }
      }
    }
  }

  private func cell(_ kind: AlertKindV1, _ channel: AlertChannel) -> some View {
    let key = AlertCell(kind: kind.kind, channel: channel)
    let waiting = routing.pending[key] != nil
    let label = String(localized: AlertText.kind(kind.kind)) + AlertRoutingPanel.separator
      + String(localized: channel.title)
    return Toggle(isOn: Binding(get: { routing.isOn(kind, channel) }, set: { change(key, $0) })) {
      Text(verbatim: label)
    }
    .toggleStyle(.designSwitch(tint: Palette.accent))
    .labelsHidden()
    .disabled(waiting || !alerts.canChange(channel))
    .opacity(waiting ? Tokens.Opacity.medium : 1)
    .gridColumnAlignment(.center)
  }

  /// Between a kind and its channel in a switch's VoiceOver name.
  static let separator = " · "

  // MARK: always on

  private var locked: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack(spacing: Tokens.Space.s) {
        Image(systemName: Self.lockSymbol)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textTertiary)
          .accessibilityHidden(true)
        Text(AlertText.alwaysOn)
          .font(Tokens.Typography.caption.weight(.semibold))
          .foregroundStyle(Palette.textTertiary)
      }
      Text(AlertText.alwaysOnNote)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textQuaternary)
        .fixedSize(horizontal: false, vertical: true)
      CappedList(alerts.lockedKinds, id: \.kind, title: AlertText.alwaysOn, endsCard: false) { _, kind in
        Text(AlertText.kind(kind.kind))
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel(Text(verbatim: String(localized: AlertText.kind(kind.kind))
            + AlertRoutingPanel.separator + String(localized: AlertText.locked)))
      }
    }
  }
}

/// A small uppercase heading inside the panel, as the System card's "This Mac".
private struct SectionLabel: View {
  let title: LocalizedStringResource

  init(_ title: LocalizedStringResource) { self.title = title }

  var body: some View {
    Text(title)
      .textCase(.uppercase)
      .font(Tokens.Typography.label)
      .tracking(Tokens.Typography.labelTracking)
      .foregroundStyle(Palette.textLabel)
      .fixedSize(horizontal: false, vertical: true)
  }
}

/// The panel before its first read: its rows' outline, never an empty grid.
public struct AlertRoutingPanelLoading: View {
  /// Rows of the outline: three channels and a few switches.
  static let rows = 6

  public init() {}

  public var body: some View { Skeleton(nil) { SkeletonRows(Self.rows) } }
}
