import Foundation

/// Presentation facts derived from a status document, shared by the apps. Pure, so tests pin them.
public enum Board {
    /// Closed trades of the day split into wins and losses, plus the day's gross result.
    public struct DayStats: Equatable, Sendable {
        public let trades: Int
        public let wins: Int
        public let losses: Int
        public let resultGrossUsd: Decimal

        /// Wins as a share of closed trades, 0 when there were none.
        public var winShare: Double { trades == 0 ? 0 : Double(wins) / Double(trades) }
    }

    public static func dayStats(_ status: StatusV1) -> DayStats {
        let results = status.tradesToday.map(\.resultGrossUsd.value)
        return DayStats(
            trades: results.count,
            wins: results.filter { $0 > 0 }.count,
            losses: results.filter { $0 < 0 }.count,
            resultGrossUsd: status.resultTodayGrossUsd.value)
    }

    /// The open positions. Contract v1 carries at most one; the apps are built for a list.
    public static func positions(_ status: StatusV1) -> [Position] {
        status.position.map { [$0] } ?? []
    }

    /// One thing that happened, for the event ticker and the journal.
    public struct Event: Identifiable, Equatable, Sendable {
        public enum Tone: Equatable, Sendable { case teal, green, blue, amber, violet, red, muted }

        public let id: String
        public let time: Date
        public let tag: String
        public let text: String
        public let tone: Tone
    }

    /// Everything the status document says happened today, newest first: entries and exits of
    /// closed trades, the open position and its stop, fences, and operator command results.
    /// Status v1 has no time for the stop itself, so the position's stop event carries the
    /// position's `openedAt`.
    public static func events(_ status: StatusV1) -> [Event] {
        var events: [Event] = []
        for (index, trade) in status.tradesToday.enumerated() {
            events.append(Event(
                id: "trade-\(index)-enter", time: trade.openedAt.date, tag: "ENTER",
                text: "\(trade.symbol) \(trade.quantity) @ \(trade.entryPrice)", tone: .teal))
            let result = trade.resultGrossUsd.value
            events.append(Event(
                id: "trade-\(index)-exit", time: trade.closedAt.date, tag: trade.exitReason.uppercased(),
                text: "\(trade.symbol) @ \(trade.exitPrice) \(signed(trade.resultGrossUsd))",
                tone: result > 0 ? .green : result < 0 ? .red : .muted))
        }
        if let position = status.position {
            events.append(Event(
                id: "position-\(position.symbol)-open", time: position.openedAt.date, tag: "OPEN",
                text: "\(position.symbol) \(position.quantity) @ \(position.entryPrice)", tone: .teal))
            events.append(Event(
                id: "position-\(position.symbol)-stop", time: position.openedAt.date,
                tag: stopTag(position.stop.state),
                text: "\(position.symbol) \(position.stop.price?.text ?? "no price")",
                tone: position.stop.state == .verified ? .green : .red))
        }
        for fence in status.fences {
            events.append(Event(
                id: "fence-\(fence.kind)", time: fence.since.date, tag: "FENCE", text: fence.text, tone: .amber))
        }
        for record in status.recentCommands {
            events.append(Event(
                id: "command-\(record.commandId)", time: record.processedAt.date,
                tag: record.outcome == .done ? "DONE" : "REFUSED",
                text: commandTitle(record.kind) + (record.cause.map { ": \($0)" } ?? ""),
                tone: record.outcome == .done ? .blue : .red))
        }
        return events.sorted { $0.time == $1.time ? $0.id > $1.id : $0.time > $1.time }
    }

    public static func stopTag(_ state: StopState) -> String {
        switch state {
        case .verified: return "STOP \u{2713}"
        case .pending: return "STOP PENDING"
        case .missing: return "NO STOP"
        case .unknown: return "STOP UNKNOWN"
        }
    }

    public static func commandTitle(_ kind: CommandKind) -> String {
        switch kind {
        case .entryStopOn: return "Pause entries"
        case .entryStopOff: return "Resume entries"
        case .cancelOwnOrders: return "Cancel own orders"
        case .flatten: return "Flatten"
        }
    }

    static func signed(_ value: DecimalString) -> String {
        value.isNegative ? value.text : "+" + value.text
    }
}
