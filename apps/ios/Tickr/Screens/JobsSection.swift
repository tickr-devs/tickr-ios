import SwiftUI
import TickrDesign
import TickrKit

/// What runs on its own on the Mac (GET /jobs): the bot service, its reconcile loop, the database
/// backup and the launchd jobs with their start times. Read while Settings is open.
struct JobsSection: View {
  /// Symbols of the rows' icons.
  static let serviceSymbol = "waveform.path.ecg"
  static let reconcileSymbol = "arrow.triangle.2.circlepath"
  static let backupSymbol = "externaldrive.fill"
  static let launchdSymbol = "clock.fill"
  /// Days in a week; launchd numbers them 0 (or 7) Sunday, 1 Monday … 6 Saturday.
  static let week = 7
  /// Shortest run of days written as a range ("Mon–Fri") rather than a list.
  static let shortestRange = 3

  @Environment(AppModel.self) private var model

  var body: some View {
    SettingsCard(L10n.Settings.jobs, note: L10n.Settings.jobsFooter) {
      if let jobs = model.jobs {
        service(jobs)
        reconcile(jobs.reconcile)
        backup(jobs.backup)
        ForEach(jobs.launchd, id: \.name) { job in
          LabeledContent {
            Text(verbatim: job.localTime + Format.separator + Self.days(job.weekdays))
              .font(.body.monospaced())
          } label: {
            Label { Text(verbatim: Self.title(job.name)) } icon: { SettingsIcon(Self.launchdSymbol, tone: .info) }
          }
        }
      } else if let error = model.jobsError {
        ReadFailureNote(L10n.ReadFailed.jobs, detail: error)
      } else {
        Text(verbatim: Format.missing).foregroundStyle(Palette.textTertiary)
      }
    }
  }

  /// The bot's state as its status reports it; a stale status proves nothing about the bot now, so
  /// it says so instead of repeating the last state.
  private func service(_ jobs: JobsV1) -> some View {
    let running = jobs.botState == .running && !jobs.statusStale
    let tone: Tone = jobs.statusStale ? .warning : running ? .accent : .neutral
    let title = jobs.statusStale ? L10n.Settings.notReported : jobs.botState?.title ?? L10n.Settings.notRunning
    return SettingsRow(L10n.Settings.botService, systemImage: Self.serviceSymbol, tone: tone) {
      StatusPill(title, tone: tone, live: running, event: running)
    }
  }

  /// A launchd job's name in the person's language; a job this app does not know reads as
  /// "Other job", never as its launchd name.
  static func title(_ name: String) -> String {
    guard let job = LaunchdJob(rawValue: name) else { return String(localized: L10n.Settings.jobOther) }
    switch job {
    case .preflight: return String(localized: L10n.Settings.jobPreflight)
    case .bot: return String(localized: L10n.Settings.jobBot)
    case .watchdog: return String(localized: L10n.Settings.jobWatchdog)
    }
  }

  /// The launchd jobs the bot installs on the Mac, by their wire names in jobs-v1.
  enum LaunchdJob: String {
    case preflight, bot, watchdog
  }

  /// The next reconcile counting down while the bot runs, else when it last ran.
  private func reconcile(_ job: ReconcileJobV1) -> some View {
    SettingsRow(L10n.Settings.reconcile, systemImage: Self.reconcileSymbol, tone: .info) {
      Group {
        if let next = job.nextAt?.date, next > model.botNow {
          HStack(spacing: Tokens.Space.xs) {
            Text(L10n.Settings.nextIn)
            Text(timerInterval: Date.now...Date.now.addingTimeInterval(next.timeIntervalSince(model.botNow)))
              .monospacedDigit()
          }
        } else if let last = job.lastAt {
          Text(L10n.Settings.lastAt(Format.clock(last.date)))
        } else {
          Text(verbatim: Format.missing)
        }
      }
      .font(.body.monospaced())
    }
  }

  /// Whether the backup's last failure is newer than its last good run (or there is no good run).
  static func backupFailed(_ job: BackupJobV1) -> Bool {
    job.lastFailedAt.map { failure in job.lastAt.map { failure.date > $0.date } ?? true } ?? false
  }

  /// Red after a newer failure, green only when a good backup exists, neutral before any.
  static func backupTone(_ job: BackupJobV1) -> Tone {
    backupFailed(job) ? .loss : job.lastAt == nil ? .neutral : .profit
  }

  /// The last good backup, or the failure when it is newer; the error and any cause below.
  @ViewBuilder
  private func backup(_ job: BackupJobV1) -> some View {
    let failed = Self.backupFailed(job)
    SettingsRow(L10n.Settings.backup, systemImage: Self.backupSymbol, tone: Self.backupTone(job)) {
      if failed, let at = job.lastFailedAt {
        StatusPill(L10n.Settings.backupFailed(Format.time(at.date)), tone: .loss)
      } else if let at = job.lastAt {
        Text(verbatim: DayText.day(at.date) + Format.separator + Format.time(at.date))
          .font(.body.monospaced())
      } else {
        Text(verbatim: Format.missing)
      }
    }
    if failed, let error = job.lastFailedError {
      InfoCaption(verbatim: error, tone: .loss)
    }
    if let cause = job.causeText {
      InfoCaption(verbatim: cause, tone: .warning)
    }
  }

  /// "Mon–Fri" for a run of days, else "Mon, Wed"; in the phone's language.
  static func days(_ weekdays: [Int]) -> String {
    let symbols = Calendar.current.shortWeekdaySymbols
    // Monday first, Sunday last, as a working week reads.
    let order = Array(Set(weekdays.map { $0 % week })).sorted { ($0 + week - 1) % week < ($1 + week - 1) % week }
    guard order.allSatisfy({ symbols.indices.contains($0) }), let first = order.first, let last = order.last else {
      return weekdays.map(String.init).joined(separator: Format.separator)
    }
    let contiguous = zip(order, order.dropFirst()).allSatisfy { ($0.0 + 1) % week == $0.1 }
    if contiguous && order.count >= shortestRange {
      return symbols[first] + Format.timeRange + symbols[last]
    }
    return order.map { symbols[$0] }.joined(separator: Format.separator)
  }
}
