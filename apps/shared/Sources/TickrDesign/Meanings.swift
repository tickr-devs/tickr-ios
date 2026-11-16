import SwiftUI
import TickrKit

// The one look of each operator-facing meaning that both apps show: a stop's protection, a
// headline's severity, a strategy verdict, and the tones TickrKit gives events and exits
// (docs/design-system.md, "One meaning, one look"). Screens read these maps; they never pick a
// colour or a symbol for these meanings themselves (check_swift_rules.py, rules `result`,
// `stopsymbol`).

// MARK: - stop protection

extension StopState {
  /// A stop the broker confirmed working: a shield with a check (the Main board's badge).
  public static let verifiedSymbol = "checkmark.shield"
  /// A stop sent and not confirmed yet: an hourglass.
  public static let pendingSymbol = "hourglass"
  /// No stop at the broker: a crossed shield.
  public static let missingSymbol = "xmark.shield"
  /// The stop's state could not be read: an exclaimed shield.
  public static let unknownSymbol = "exclamationmark.shield"
  /// A stop's price level next to its figure (the Main board's "Stop" metric): a bare shield.
  public static let levelSymbol = "shield"

  /// The symbol of this state.
  public var symbol: String {
    switch self {
    case .verified: return Self.verifiedSymbol
    case .pending: return Self.pendingSymbol
    case .missing: return Self.missingSymbol
    case .unknown: return Self.unknownSymbol
    }
  }

  /// Verified profit (green), pending warning (amber: sent, not confirmed yet), missing or
  /// unknown loss (red: no protection, a danger state). Mockup v100.
  public var tone: Tone {
    switch self {
    case .verified: return .profit
    case .pending: return .warning
    case .missing, .unknown: return .loss
    }
  }

  /// The states from best to worst, for picking the worst of several.
  static let bestToWorst: [StopState] = [.verified, .pending, .unknown, .missing]

  /// How bad a state is: its place in `bestToWorst`.
  var rank: Int { Self.bestToWorst.firstIndex(of: self) ?? Self.bestToWorst.count }

  /// The worst of several stops' states; nil for none.
  public static func worst(_ states: [StopState]) -> StopState? {
    states.max { $0.rank < $1.rank }
  }

  /// The tone of a set of positions' stops: the worst one's, neutral with no position.
  public static func combinedTone(_ states: [StopState]) -> Tone {
    worst(states)?.tone ?? .neutral
  }

  /// The symbol of a set of positions' stops (a safety tile): the worst one's, so an unverified
  /// stop never shows a check; the bare stop shield with no position.
  public static func combinedSymbol(_ states: [StopState]) -> String {
    worst(states)?.symbol ?? levelSymbol
  }

  /// A day trade's stop as the flow reports it, read as a position's stop state (a stop never
  /// confirmed before the trade ended counts as missing).
  public init(_ flow: FlowStopState) {
    switch flow {
    case .verified: self = .verified
    case .pending: self = .pending
    case .neverVerified: self = .missing
    case .unknown: self = .unknown
    }
  }

  /// The tone of the live flow's broker-stop stage (Mac Overview, the Mac menu bar, iOS Home):
  /// neutral with no open position unless a trade of the day ended without a confirmed stop (or
  /// one the bot cannot account for); else the worst of the open positions' and the day's stops.
  public static func stageTone(open: [StopState], day: [FlowStopState] = []) -> Tone {
    let dayStates = day.map { StopState($0) }
    let dayFailed = dayStates.contains { $0 == .missing || $0 == .unknown }
    guard !open.isEmpty || dayFailed else { return .neutral }
    return combinedTone(open + dayStates)
  }
}

/// A position's protection as a glyph tile: the state's symbol in its tone, pulsing once each time
/// the state or the stop's price changes while the position is unprotected. Its hint and
/// VoiceOver label name the symbol and the state ("ABCD · pending"). The same in both apps;
/// `style` only sets its size (`.tile` beside a large symbol, `.compact` in rows).
public struct StopGlyph: View {
  let state: StopState
  let symbol: String
  let price: DecimalString?
  let style: StateGlyph.Style

  /// Between the symbol and the state in the label.
  static let separator = " · "

  public init(state: StopState, symbol: String, price: DecimalString? = nil, style: StateGlyph.Style = .compact) {
    self.state = state
    self.symbol = symbol
    self.price = price
    self.style = style
  }

  public var body: some View {
    StateGlyph(state.symbol, tone: state.tone, label: Text(verbatim: Self.label(state, symbol: symbol)),
      live: !state.isProtected, event: [AnyHashable(state), AnyHashable(price)], style: style)
  }

  /// "ABCD · verified": the glyph's label, in the person's language.
  public static func label(_ state: StopState, symbol: String) -> String {
    symbol + separator + Board.stopStateTitle(state)
  }
}

/// A position's protection as a small dot in its stop's tone, for a position's tab: present on
/// every tab, so a tab without one never reads as protected. It pulses once when an unprotected
/// stop changes. Decorative for VoiceOver: the tab says the state (`StopGlyph.label`).
public struct StopDot: View {
  let state: StopState

  public init(_ state: StopState) {
    self.state = state
  }

  public var body: some View {
    PulseDot(state.tone.fill, size: Tokens.Size.dotSmall, pulsing: !state.isProtected, event: state)
  }
}

// MARK: - headline severity

extension Severity {
  /// The tone of a headline with this severity: calm in profit, attention in warning, alarm in
  /// loss. `Headline.tone` refines the calm one.
  public var tone: Tone {
    switch self {
    case .ok: return .profit
    case .attention: return .warning
    case .alarm: return .loss
    }
  }
}

extension Headline {
  /// The headline's tone, as the boards draw it: a calm headline about held positions, every one
  /// protected, in the accent (Main "holding", MacMenuBar, IOSHome); a calm one with nothing held
  /// ("Entries allowed") in profit (Main "scanning"); attention in warning; alarm in loss.
  public var tone: Tone {
    severity == .ok && holding ? .accent : severity.tone
  }
}

// MARK: - verdicts

extension Verdict {
  /// The text colour of a verdict wherever it is written (the Chart's decisions, Watching
  /// closely), as the boards draw it: ENTER and HOLD in the accent (MacChart's explain card),
  /// WATCH in info, IGNORE in the series pink (Main, MacChart), EXIT in warning (no board draws
  /// an EXIT verdict; the Mac's existing colour). Always a text role.
  public var color: Color {
    switch self {
    case .enter, .hold: return Palette.accentText
    case .watch: return Palette.infoText
    case .ignore: return Palette.seriesATRText
    case .exit: return Palette.warningText
    }
  }

  /// The light and dark values of `color` (`PaletteContrastTests`).
  public var textSwatch: Swatch {
    switch self {
    case .enter, .hold: return .accentText
    case .watch: return .infoText
    case .ignore: return .seriesATRText
    case .exit: return .warningText
    }
  }
}

// MARK: - event and exit tones

extension Tone {
  /// The design tone of a TickrKit event tone (`Board.Event.Tone`, `Board.exitTone`): the one map
  /// from the bot's meanings to colours, so an exit forced at the session's end is amber on both
  /// apps and a protection failure red whatever the result.
  public init(_ tone: Board.Event.Tone) {
    switch tone {
    case .teal: self = .accent
    case .green: self = .profit
    case .blue: self = .info
    case .amber: self = .warning
    case .violet: self = .highlight
    case .red: self = .loss
    case .muted: self = .neutral
    }
  }

  /// The tone of a trade's reason tag, both apps (mockup v99, MacTrades and IOSActivity), by the
  /// reason alone, never by the result: the strategy's exit in the accent, a stop-out in the
  /// series pink, a protection failure (stop rejected, unprotected too long) in loss, every
  /// other close (end of day, a plain close, the operator, a lost stream, a reason this app does
  /// not know) neutral.
  public static func exit(_ reason: String) -> Tone {
    switch Board.exitLook(reason) {
    case .strategy: .accent
    case .stoppedOut: .series
    case .protectionFailure: .loss
    case .other: .neutral
    }
  }

  /// The tag of an open position (OPEN), in the accent like the strategy's exit.
  public static let openPosition = Tone.accent
  /// The tag of a signal the risk layer refused (REFUSED).
  public static let refused = Tone.warning
  /// The tag of a signal never evaluated, made too late to act on (NOT EVALUATED).
  public static let notEvaluated = Tone.neutral
}
