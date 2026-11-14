import ApertureDesign
import ApertureKit
import Foundation
import Observation

/// Refresh pacing of the app. The status poll follows the server's `poll_seconds`; the rest are
/// app-side choices, kept together here.
enum Pace {
    /// Status poll before the first answer says the server's poll_seconds.
    static let initialPollSeconds: Double = 3
    /// Day list and today's day document (trades change at most a few times a day).
    static let historySeconds: Double = 30
    /// Bars of the open positions (one new M1 bar a minute).
    static let barsSeconds: Double = 15
    /// How long a command toast stays on screen.
    static let toastSeconds: Double = 6
}

/// A command the operator sent, followed until the bot reports its outcome.
public struct SentCommand: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: CommandKind
    public let title: String
    public var outcome: CommandOutcome?
    public var cause: String?
    public var warning: String?
}

/// One open position as the app shows it (v1 status carries 0 or 1; the UI is built for a list).
public struct PositionRow: Identifiable, Equatable, Sendable {
    public let position: Position
    /// Close of the latest captured M1 bar, with its start time; nil until bars arrive.
    public let lastBarClose: Decimal?
    public let lastBarAt: Date?
    /// Closes since the entry, for the small chart.
    public let closes: [Decimal]

    public var id: String { position.symbol }
    public var entry: Decimal { position.entryPrice.value }
    public var stop: Decimal? { position.stop.price?.value }
    public var quantity: Decimal { position.quantity.value }

    public var unrealized: Decimal? { lastBarClose.map { ($0 - entry) * quantity } }
    public var resultR: Decimal? {
        guard let last = lastBarClose else { return nil }
        return Risk.multiple(entry: entry, stop: stop, price: last)
    }
}

/// Everything the windows and the menu bar show. Polls the local API; never talks to the broker.
@MainActor
@Observable
public final class AppModel {
    // Connection.
    public private(set) var baseURL: URL
    private var client: APIClient

    // Live state.
    public private(set) var response: StatusResponseV1?
    public private(set) var fetchError: String?
    public private(set) var settings: SettingsV1?
    public private(set) var settingsError: String?

    // Navigation (the sidebar selection lives here so any card can jump to a section).
    var section: AppSection = .overview

    // History.
    public private(set) var days: [DaySummary] = []
    public private(set) var historyError: String?
    /// nil = today (live). Otherwise a recorded day from `days`.
    public var selectedDay: WireDate? { didSet { if oldValue != selectedDay { Task { await loadSelectedDay() } } } }
    public private(set) var dayDocument: DayV1?
    public private(set) var todayDocument: DayV1?

    // Positions with their latest bars.
    private var barsBySymbol: [String: BarsV1] = [:]

    // Commands.
    public private(set) var sending = false
    public private(set) var sent: [SentCommand] = []
    public private(set) var toast: SentCommand?

    private var tasks: [Task<Void, Never>] = []

    public init(baseURL: URL) {
        self.baseURL = baseURL
        self.client = APIClient(baseURL: baseURL)
    }

    // MARK: derived

    public var status: StatusV1? { response?.status }
    public var headline: Headline { Headline.make(response: response, fetchError: fetchError) }
    public var today: WireDate { WireDate(newYorkDateOf: Date()) }
    public var isLive: Bool { selectedDay == nil || selectedDay == today }
    public var shownDay: WireDate { selectedDay ?? today }

    /// Commands make sense only for the live day with a status the app can trust.
    public var commandsEnabled: Bool {
        isLive && !sending && status != nil && response?.stale == false && fetchError == nil
    }

    public var positions: [PositionRow] {
        guard isLive, let position = status?.position else { return [] }
        let bars = barsBySymbol[position.symbol]?.bars.filter { $0.start.date >= position.openedAt.date.addingTimeInterval(-60) } ?? []
        let last = barsBySymbol[position.symbol]?.bars.last
        let fresh = last.map { barIsFresh(start: $0.start.date) } ?? false
        return [PositionRow(position: position, lastBarClose: fresh ? last?.close.value : nil, lastBarAt: last?.start.date,
                            closes: bars.map(\.close.value))]
    }

    /// A captured M1 bar is fresh while its close (start + one minute) is no older than the
    /// server's `status_stale_seconds`. Without settings nothing counts as fresh.
    func barIsFresh(start: Date, now: Date = Date()) -> Bool {
        guard let settings else { return false }
        let staleSeconds = NSDecimalNumber(decimal: settings.statusStaleSeconds.value).doubleValue
        let barClose = start.addingTimeInterval(Self.barSeconds)
        return now.timeIntervalSince(barClose) <= staleSeconds
    }

    /// Length of one captured bar (M1).
    static let barSeconds: TimeInterval = 60

    /// Trades of the shown day: live from status for today, else from the day document.
    public var shownTrades: [DayTrade] {
        if isLive { return todayDocument?.trades ?? [] }
        return dayDocument?.trades ?? []
    }

    public var shownResult: Decimal {
        if isLive { return status?.resultTodayGrossUsd.value ?? 0 }
        return dayDocument?.resultGrossUsd.value ?? 0
    }

    /// Running sum of trade results through the day, starting at 0, for the sparkline.
    public var cumulativeResults: [Double] {
        var sum: Decimal = 0
        var values: [Double] = [0]
        let results: [Decimal] = isLive
            ? (status?.tradesToday.map(\.resultGrossUsd.value) ?? [])
            : shownTrades.map(\.resultGrossUsd.value)
        for value in results {
            sum += value
            values.append(NSDecimalNumber(decimal: sum).doubleValue)
        }
        return values
    }

    public var shownTradeCount: Int {
        isLive ? (status?.tradesToday.count ?? 0) : shownTrades.count
    }

    public var shownWins: Int {
        let results = isLive ? (status?.tradesToday.map(\.resultGrossUsd.value) ?? []) : shownTrades.map(\.resultGrossUsd.value)
        return results.filter { $0 > 0 }.count
    }

    public var shownLosses: Int {
        let results = isLive ? (status?.tradesToday.map(\.resultGrossUsd.value) ?? []) : shownTrades.map(\.resultGrossUsd.value)
        return results.filter { $0 < 0 }.count
    }

    /// Previous and next recorded days around the shown one (days are newest first).
    public var previousDay: WireDate? { days.map(\.day).first { $0 < shownDay } }
    public var nextDay: WireDate? { days.map(\.day).reversed().first { $0 > shownDay } }

    // MARK: lifecycle

    public func start() {
        guard tasks.isEmpty else { return }
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshStatus()
                let seconds = self.response.map { NSDecimalNumber(decimal: $0.pollSeconds.value).doubleValue }
                    ?? Pace.initialPollSeconds
                try? await Task.sleep(for: .seconds(max(seconds, 1)))
            }
        })
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshHistory()
                try? await Task.sleep(for: .seconds(Pace.historySeconds))
            }
        })
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshPositionBars()
                try? await Task.sleep(for: .seconds(Pace.barsSeconds))
            }
        })
    }

    public func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
    }

    /// Point the app at another API address (Settings › Advanced).
    public func connect(to url: URL) {
        guard url != baseURL else { return }
        baseURL = url
        client = APIClient(baseURL: url)
        response = nil
        settings = nil
        days = []
        dayDocument = nil
        todayDocument = nil
        barsBySymbol = [:]
        Task {
            await refreshStatus()
            await refreshHistory()
        }
    }

    // MARK: reads

    public func refreshStatus() async {
        do {
            response = try await client.status()
            fetchError = nil
            resolveSentCommands()
            // Counts come from status, the trade list from /days/<today>: when status shows a
            // trade the list lacks, read the list now instead of waiting for the history poll.
            if let count = status?.tradesToday.count, let document = todayDocument, count != document.trades.count {
                await refreshHistory()
            }
        } catch {
            fetchError = Self.describe(error)
        }
        if settings == nil { await refreshSettings() }
    }

    public func refreshSettings() async {
        do {
            settings = try await client.settings()
            settingsError = nil
        } catch {
            settingsError = Self.describe(error)
        }
    }

    public func refreshHistory() async {
        do {
            days = try await client.days().days
            todayDocument = try await client.day(today)
            historyError = nil
        } catch {
            historyError = Self.describe(error)
        }
    }

    private func loadSelectedDay() async {
        guard let day = selectedDay, day != today else {
            dayDocument = nil
            return
        }
        do {
            let document = try await client.day(day)
            guard day == selectedDay else { return }
            dayDocument = document
            historyError = nil
        } catch {
            guard day == selectedDay else { return }
            dayDocument = nil
            historyError = Self.describe(error)
        }
    }

    public func refreshPositionBars() async {
        guard let symbol = status?.position?.symbol else { return }
        do {
            barsBySymbol[symbol] = try await client.bars(symbol: symbol, day: today)
        } catch {
            // The position still shows its entry and stop; only "last" stays empty.
            barsBySymbol[symbol] = nil
        }
    }

    // MARK: day navigation

    public func showPreviousDay() { if let day = previousDay { selectedDay = day } }
    public func showNextDay() { selectedDay = nextDay.flatMap { $0 == today ? nil : $0 } }
    public func showToday() { selectedDay = nil }

    // MARK: commands

    public func send(_ command: OperatorCommand, title: String) async {
        // A confirmation alert can stay open while the status goes stale or the day changes:
        // check again at the moment of sending, never trust the state the alert was opened in.
        guard commandsEnabled else {
            show(SentCommand(id: UUID().uuidString, kind: command.kind, title: title, outcome: .refused,
                             cause: "not sent: the app cannot trust the bot's status right now", warning: nil))
            return
        }
        sending = true
        defer { sending = false }
        do {
            let accepted = try await client.send(command)
            let record = SentCommand(id: accepted.command.commandId, kind: command.kind, title: title,
                                     outcome: nil, cause: nil, warning: accepted.warning)
            sent.insert(record, at: 0)
            show(record)
        } catch {
            show(SentCommand(id: UUID().uuidString, kind: command.kind, title: title, outcome: .refused,
                             cause: "not sent: " + Self.describe(error), warning: nil))
        }
        await refreshStatus()
    }

    private func resolveSentCommands() {
        guard let records = status?.recentCommands else { return }
        for index in sent.indices where sent[index].outcome == nil {
            if let record = records.first(where: { $0.commandId == sent[index].id }) {
                sent[index].outcome = record.outcome
                sent[index].cause = record.cause
                show(sent[index])
            }
        }
    }

    private func show(_ command: SentCommand) {
        toast = command
        let id = command.id
        Task {
            try? await Task.sleep(for: .seconds(Pace.toastSeconds))
            if toast?.id == id && toast?.outcome == command.outcome { toast = nil }
        }
    }

    static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}
