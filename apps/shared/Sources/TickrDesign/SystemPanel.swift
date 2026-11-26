import SwiftUI
import TickrKit

// The System card's content on both apps (GET /system, mockup v120): the Webull link, the
// morning check and model training, then under "This Mac" the watchdog with its restarts and the
// no-sleep hold. Each app wraps it in its own card with `SystemText.title` and `SystemPill`;
// everything inside is this one view. The Mac rows come only from the API's `host` block, so a
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
    return SystemRow(SystemText.link, symbol: Self.linkSymbol, health: health,
      note: link.causeText.map { Text(verbatim: $0) }
        ?? Text(SystemText.linkNote(Money.plain(link.maxAgeSeconds.value, fractionDigits: 0)))) {
      VStack(alignment: .trailing, spacing: Tokens.Space.xxs) {
        if let read = link.lastReadAt {
          Text(SystemText.ago(SystemCard.Age(since: read.date, now: now)))
            .foregroundStyle(health.tone.text)
        } else {
          Text(SystemText.unknown).foregroundStyle(Palette.textQuaternary)
        }
        if let stream = link.stream {
          Text(Self.stream(stream)).font(Tokens.Typography.annotation).foregroundStyle(Palette.textQuaternary)
        }
      }
    }
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
      note: check.map { Text(Self.ranBy($0)) } ?? system.morningCheckCauseText.map { Text(verbatim: $0) }) {
      if let check {
        Text(Self.outcome(check)).foregroundStyle(health.tone.text)
      } else {
        Text(SystemText.unknown).foregroundStyle(Palette.textQuaternary)
      }
    }
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
    case .failed:
      return SystemText.failed(String(localized: SystemText.check(check.failedCheck?.name ?? "")))
    }
  }

  private var trainingRow: some View {
    let health = SystemCard.training(system)
    let training = system.training
    let note: Text? = training.map {
      Text(SystemText.trainingNote($0.job, $0.done, $0.total,
        String(localized: SystemText.ago(SystemCard.Age(since: $0.updatedAt.date, now: now)))))
    } ?? system.trainingCauseText.map { Text(verbatim: $0) }
    return VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      SystemRow(SystemText.training, symbol: Self.trainingSymbol, health: health,
        tone: training?.state == .running ? .highlight : nil, note: note) {
        if let training {
          switch training.state {
          case .running:
            Text(verbatim: Percent.plain(fraction: Decimal(training.fraction)))
              .foregroundStyle(Tone.highlight.text)
          case .done: Text(SystemText.trainingDone).foregroundStyle(Tone.profit.text)
          case .failed: Text(SystemText.trainingFailed).foregroundStyle(Tone.warning.text)
          }
        } else {
          Text(SystemText.idle).foregroundStyle(Palette.textQuaternary)
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
      note: watchdog.causeText.map { Text(verbatim: $0) } ?? Text(Self.lastCheck(watchdog))) {
      if watchdog.cause != nil {
        Text(SystemText.unknown).foregroundStyle(Palette.textQuaternary)
      } else {
        Text(watchdog.startedDay == today ? SystemText.startedToday : SystemText.notStartedToday)
          .foregroundStyle(watchdog.startedDay == today ? Tone.profit.text : Palette.textTertiary)
      }
    }
  }

  static func lastCheck(_ watchdog: WatchdogV1) -> LocalizedStringResource {
    guard let at = watchdog.lastCheckAt else { return SystemText.noCheckYet }
    let time = DayText.day(at.date) + SystemPanel.separator + ClockText.minutes(at.date)
    if watchdog.lastCheckRead != true { return SystemText.lastCheckFailed(time) }
    return watchdog.lastCheckFlat == true ? SystemText.lastCheckFlat(time) : SystemText.lastCheckOpen(time)
  }

  private func sleepRow(_ mac: HostV1) -> some View {
    let sleep = mac.sleep
    let health = SystemCard.sleep(mac, botRunning: system.botRunning)
    let note = Self.sleepNote(sleep, botRunning: system.botRunning)
    return SystemRow(SystemText.sleep, symbol: Self.sleepSymbol, health: health, note: note) {
      switch sleep.state {
      case .held: Text(SystemText.keptAwake).foregroundStyle(health.tone.text)
      case .notHeld: Text(SystemText.maySleep).foregroundStyle(health.tone.text)
      case .unknown: Text(SystemText.unknown).foregroundStyle(Palette.textQuaternary)
      }
    }
  }

  /// Under the hold: why it is unknown, how many processes hold it, or that it is not needed now.
  static func sleepNote(_ sleep: SleepV1, botRunning: Bool) -> Text? {
    if let cause = sleep.causeText { return Text(verbatim: cause) }
    switch sleep.state {
    case .held: return sleep.holds.map { Text(SystemText.holds($0)) }
    case .notHeld: return botRunning ? nil : Text(SystemText.notNeededNow)
    case .unknown: return nil
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
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Circle().fill(tone.fill).frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        HStack(alignment: .firstTextBaseline) {
          Text(verbatim: DayText.day(restart.at.date) + SystemPanel.separator + ClockText.minutes(restart.at.date))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textSecondary)
          Spacer(minLength: Tokens.Space.s)
          Text(Self.outcome(restart.outcome)).font(Tokens.Typography.captionMono).foregroundStyle(tone.text)
        }
        if let why = Self.why(restart) {
          why.font(Tokens.Typography.caption).foregroundStyle(Palette.textTertiary)
        }
      }
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
