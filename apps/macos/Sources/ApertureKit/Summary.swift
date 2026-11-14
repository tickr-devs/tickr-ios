import Foundation

/// How alarming the current state is; drives colours and the menu-bar symbol.
public enum Severity: Int, Comparable, Sendable {
    case ok = 0, attention = 1, alarm = 2

    public static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
}

/// The one line a person reads first, plus its severity. Pure, so iOS and tests share it.
public struct Headline: Equatable, Sendable {
    public let text: String
    public let severity: Severity

    public init(text: String, severity: Severity) {
        self.text = text
        self.severity = severity
    }

    /// `fetchError` is the last failure to read /status; it wins over an older good response.
    public static func make(response: StatusResponseV1?, fetchError: String?) -> Headline {
        if let fetchError {
            return Headline(text: "\(fetchError). Entry status unknown.", severity: .alarm)
        }
        guard let response else {
            return Headline(text: "Connecting to the local API…", severity: .attention)
        }
        guard let status = response.status, !response.stale else {
            return Headline(text: response.summary, severity: .alarm)
        }
        if let position = status.position, position.stop.state != .verified {
            return Headline(
                text: "Position \(position.symbol) has no verified stop (\(position.stop.state.rawValue)). "
                    + response.summary,
                severity: .alarm)
        }
        return Headline(text: response.summary, severity: status.entryBlock == nil ? .ok : .attention)
    }
}

public enum Display {
    /// Short local time, for tables.
    public static func time(_ time: WireTime?) -> String {
        guard let time else { return "—" }
        return time.date.formatted(date: .omitted, time: .standard)
    }

    public static func usd(_ value: DecimalString) -> String { "\(value.text) USD" }

    public static func commandTitle(_ kind: CommandKind) -> String {
        switch kind {
        case .entryStopOn: return "Entry stop on"
        case .entryStopOff: return "Entry stop off"
        case .cancelOwnOrders: return "Cancel own orders"
        case .flatten: return "Flatten"
        }
    }
}
