import SwiftUI
import TickrKit

// The System card's content on both apps (GET /system, mockup v134): the broker connection, the
// morning check and the next model version's training, then under "This Mac" the watchdog with its
// restarts and the no-sleep hold. A row says its value; a note under it appears only when the row
// needs a look (v134 "simple"), so an all-good card is a short list of values. Each app wraps it
// in its own card with `SystemText.title` and `SystemPill`; everything inside is this one view. The Mac rows come only from the API's `host` block, so a
// bot on a server shows the same card without them.

extension SystemCard.Health {
  /// The tone of a row in this health: red only for danger.
  public var tone: Tone {
    switch self {
    case .good: return .profit
    case .attention: return .warning
    case .danger: return .loss
    case .idle, .unknown: return .neutral
    }
  }
}

/// The card's summary: "All good", or how many rows need a look (red when one is dangerous).
public struct SystemPill: View {
  let system: SystemV1

  public init(_ system: SystemV1) { self.system = system }

  public var body: some View {
    let count = SystemCard.needingALook(system)
    let danger = SystemCard.all(system).contains(.danger)
    StatusPill(count == 0 ? SystemText.allGood : SystemText.needALook(count),
      tone: count == 0 ? .profit : danger ? .loss : .warning)
      .contentTransition(.opacity)
  }
}

public struct SystemPanel: View {
  /// Symbols of the rows' tiles.
  static let linkSymbol = "link"
  static let checkSymbol = "checkmark.seal.fill"
  static let trainingSymbol = "chart.bar.fill"
  static let watchdogSymbol = "shield.lefthalf.filled"
  static let sleepSymbol = "moon.zzz.fill"
  /// Between a day and its time.
  static let separator = " · "

  let system: SystemV1
  /// The bot's clock now, so ages tick between reads.
  let now: Date

  public init(_ system: SystemV1, now: Date) {
    self.system = system
    self.now = now
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      linkRow
      morningRow
      trainingRow
      if let mac = system.mac {
        HStack(spacing: Tokens.Space.s) {
          Text(SystemText.thisMac)
            .textCase(.uppercase)
            .font(Tokens.Typography.label)
            .tracking(Tokens.Typography.labelTracking)
            .foregroundStyle(Palette.textLabel)
          Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
        }
        watchdogRow(mac)
        sleepRow(mac)
        restarts(mac.watchdog)
      }
    }
  }

  // MARK: rows

  private var linkRow: some View {
    let link = system.brokerLink
    let health = SystemCard.link(system)
    return SystemRow(SystemText.link, symbol: Self.linkSymbol, health: health, note: Self.linkNote(link, health)) {
      VStack(alignment: .trailing, spacing: Tokens.Space.xxs) {
        if let read = link.lastReadAt {
          Text(SystemText.ago(SystemCard.Age(since: read.date, now: now)))
            .foregroundStyle(health.tone.text)
        } else {
          Text(SystemText.unknown).foregroundStyle(Palette.textQuaternary)
        }
        if let stream = link.stream, stream != .fresh {
          Text(Self.stream(stream)).font(Tokens.Typography.annotation).foregroundStyle(Palette.textQuaternary)
        }
      }
    }
  }

  /// Under the link only when it needs a look: why it is unknown, or the read age new entries need
  /// (blocked once the read is past it).
  static func linkNote(_ link: BrokerLinkV1, _ health: SystemCard.Health) -> Text? {
    if let cause = link.causeText { return Text(verbatim: cause) }
    guard health == .attention else { return nil }
    let seconds = Money.plain(link.maxAgeSeconds.value, fractionDigits: 0)
    return Text(link.state == .stale ? SystemText.linkBlocked(seconds) : SystemText.linkNote(seconds))
  }

  static func stream(_ health: StreamHealth) -> LocalizedStringResource {
    switch health {
    case .fresh: return SystemText.streamFresh
    case .quiet: return SystemText.streamQuiet
    case .lost: return SystemText.streamLost
    case .off: return SystemText.streamOff
    }
  }

  private var morningRow: some View {
    let health = SystemCard.morningCheck(system)
    let check = system.morningCheck
    return SystemRow(SystemText.morningCheck, symbol: Self.checkSymbol, health: health,
      note: Self.morningNote(check, health) ?? system.morningCheckCauseText.map { Text(verbatim: $0) }) {
      if let check {
        Text(Self.outcome(check)).foregroundStyle(health.tone.text)
      } else {
        Text(SystemText.unknown).foregroundStyle(Palette.textQuaternary)
      }
    }
  }

  /// Under the check: nothing on today's pass; today's failure names the check (and that the bot
  /// will not start on it); any other result says which job ran it and when.
  static func morningNote(_ check: MorningCheckV1?, _ health: SystemCard.Health) -> Text? {
    guard let check, health != .good else { return nil }
    // An earlier day's result is history (idle): its day matters more than its check.
    guard check.outcome == .failed, health != .idle else { return Text(ranBy(check)) }
    let name = String(localized: SystemText.check(check.failedCheck?.name ?? ""))
    return Text(check.blocksStart ? SystemText.willNotStart(name) : SystemText.checkFailed(name))
  }

  static func ranBy(_ check: MorningCheckV1) -> LocalizedStringResource {
    let day = DayText.day(check.day)
    let time = ClockText.minutes(check.startedAt.date)
    return check.job == .preflight ? SystemText.ranByMorningJob(day, time) : SystemText.ranByBotStart(day, time)
  }

  static func outcome(_ check: MorningCheckV1) -> LocalizedStringResource {
    switch check.outcome {
    case .ready: return SystemText.passed(ClockText.minutes(check.finishedAt.date))
    case .noSession: return SystemText.noSession
    case .configInvalid: return SystemText.configInvalid
    case .failed: return SystemText.failed(ClockText.minutes(check.finishedAt.date))
    }
  }

  private var trainingRow: some View {
    let health = SystemCard.training(system)
    let training = system.training
    let note = training == nil ? system.trainingCauseText.map { Text(verbatim: $0) } : nil
    return VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      SystemRow(SystemText.training, symbol: Self.trainingSymbol, health: health,
        tone: training?.state == .running ? .highlight : nil, note: note) {
        if let training {
          switch training.state {
          case .running:
            Text(SystemText.trainingPercent(Percent.plain(fraction: Decimal(training.fraction))))
              .foregroundStyle(Tone.highlight.text)
          case .done: Text(SystemText.trainingDone).foregroundStyle(Tone.profit.text)
          case .failed: Text(SystemText.trainingFailed).foregroundStyle(Tone.warning.text)
          }
        } else {
          Text(SystemText.notTraining).foregroundStyle(Palette.textQuaternary)
        }
      }
      if let training, training.state == .running {
        MeterBar(fraction: training.fraction, tone: .highlight)
      }
      if let cause = training?.causeText {
        InfoCaption(verbatim: cause, tone: .warning)
      }
    }
  }

  private func watchdogRow(_ mac: HostV1) -> some View {
    let watchdog = mac.watchdog
    let today = SystemCard.today(system)
    let health = SystemCard.watchdog(mac, today: today)
    return SystemRow(SystemText.watchdog, symbol: Self.watchdogSymbol, health: health,
      note: watchdog.causeText.map { Text(verbatim: $0) } ?? Self.lastCheck(watchdog).map { Text($0) }) {
      if watchdog.cause != nil {
        Text(SystemText.unknown).foregroundStyle(Palette.textQuaternary)
      } else {
        Text(watchdog.startedDay == today ? SystemText.watching : SystemText.notStartedToday)
          .foregroundStyle(watchdog.startedDay == today ? Tone.profit.text : Palette.textTertiary)
      }
    }
  }

  /// Its latest broker check, only when it found something: the read failed or a trade was left
  /// open. A check that found the account flat, or none yet, says nothing.
  static func lastCheck(_ watchdog: WatchdogV1) -> LocalizedStringResource? {
    guard let at = watchdog.lastCheckAt else { return nil }
    let time = DayText.day(at.date) + SystemPanel.separator + ClockText.minutes(at.date)
    if watchdog.lastCheckRead != true { return SystemText.lastCheckFailed(time) }
    return watchdog.lastCheckFlat == true ? nil : SystemText.lastCheckOpen(time)
  }

  private func sleepRow(_ mac: HostV1) -> some View {
    let sleep = mac.sleep
    let health = SystemCard.sleep(mac, botRunning: system.botRunning)
    return SystemRow(SystemText.sleep, symbol: Self.sleepSymbol, health: health,
      note: sleep.causeText.map { Text(verbatim: $0) }) {
      switch sleep.state {
      case .held: Text(SystemText.keptAwake).foregroundStyle(health.tone.text)
      case .notHeld: Text(SystemText.maySleep).foregroundStyle(health.tone.text)
      case .unknown: Text(SystemText.unknown).foregroundStyle(Palette.textQuaternary)
      }
    }
  }

  // MARK: restarts

  @ViewBuilder private func restarts(_ watchdog: WatchdogV1) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      Text(SystemText.restarts)
        .textCase(.uppercase)
        .font(Tokens.Typography.label)
        .tracking(Tokens.Typography.labelTracking)
        .foregroundStyle(Palette.textLabel)
      if watchdog.restarts.isEmpty {
        Text(SystemText.noRestarts).font(Tokens.Typography.caption).foregroundStyle(Palette.textTertiary)
      } else {
        CappedList(watchdog.restarts, id: \.at, title: SystemText.restarts, limit: Tokens.Lists.restartRows) { _, restart in
          RestartRow(restart: restart)
        }
      }
    }
  }
}

/// One watchdog restart: when (New York), its outcome and why.
struct RestartRow: View {
  let restart: WatchdogRestartV1

  var body: some View {
    let tone = Self.tone(restart.outcome)
    // One line as on the design: when, why (it wraps, never cut), then the outcome.
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Circle().fill(tone.fill).frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
      Text(verbatim: DayText.day(restart.at.date) + SystemPanel.separator + ClockText.minutes(restart.at.date))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize()
      if let why = Self.why(restart) {
        why.font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        Spacer(minLength: Tokens.Space.s)
      }
      Text(Self.outcome(restart.outcome)).font(Tokens.Typography.captionMono).foregroundStyle(tone.text)
        .fixedSize()
    }
    .accessibilityElement(children: .combine)
  }

  static func tone(_ outcome: RestartOutcome) -> Tone {
    switch outcome {
    case .started: return .accent
    case .refused: return .warning
    case .failed: return .loss
    }
  }

  static func outcome(_ outcome: RestartOutcome) -> LocalizedStringResource {
    switch outcome {
    case .started: return SystemText.restartStarted
    case .refused: return SystemText.restartRefused
    case .failed: return SystemText.restartFailed
    }
  }

  /// The cause when it failed or was refused; otherwise why the bot was started.
  /// Why it ran: its cause, an early restart for a resting entry, or the trades open while the bot was
  /// down; nothing when the record says none of these.
  static func why(_ restart: WatchdogRestartV1) -> Text? {
    if let cause = restart.causeText { return Text(verbatim: cause) }
    if restart.early { return Text(SystemText.restartEarly) }
    return restart.openTrades.map { Text(SystemText.restartDown($0)) }
  }
}

/// The card before its first read: its rows' outline, never zeros or "unknown".
public struct SystemPanelLoading: View {
  /// Rows of the outline: the card's three portable rows and the Mac's two.
  static let rows = 5

  public init() {}

  // The card's title names what loads, so the skeleton has no label of its own, but its bar runs.
  public var body: some View { Skeleton(nil, runs: true) { SkeletonRows(Self.rows) } }
}

/// A row of the card: a tile with the row's symbol in its tone, the title with a note under it,
/// and the value on the trailing edge. Text wraps, never cut.
struct SystemRow<Value: View>: View {
  let title: LocalizedStringResource
  let symbol: String
  let tone: Tone
  let note: Text?
  let value: Value

  init(
    _ title: LocalizedStringResource, symbol: String, health: SystemCard.Health, tone: Tone? = nil, note: Text?,
    @ViewBuilder value: () -> Value
  ) {
    self.title = title
    self.symbol = symbol
    self.tone = tone ?? health.tone
    self.note = note
    self.value = value()
  }

  var body: some View {
    HStack(alignment: .top, spacing: Tokens.Space.m) {
      Image(systemName: symbol)
        .font(Tokens.Typography.caption.weight(.semibold))
        .foregroundStyle(tone == .neutral ? Palette.textTertiary : tone.text)
        .frame(width: Tokens.Size.iconButtonCompact, height: Tokens.Size.iconButtonCompact)
        .background(tone.fill.opacity(Tokens.Opacity.wash),
          in: RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(title).font(Tokens.Typography.body).foregroundStyle(Palette.textSecondary)
        if let note {
          note.font(Tokens.Typography.captionMono).foregroundStyle(Palette.textQuaternary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      value
        .font(Tokens.Typography.calloutMono)
        .multilineTextAlignment(.trailing)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }
}
