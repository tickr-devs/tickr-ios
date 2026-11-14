import ApertureKit
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// The headline: the single entry-blocking reason in plain words, coloured by severity.
public struct HeadlineView: View {
    let headline: Headline

    public init(headline: Headline) { self.headline = headline }

    public var body: some View {
        Label(headline.text, systemImage: headline.severity.symbolName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(headline.severity.color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(headline.severity.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .textSelection(.enabled)
    }
}

/// Operator command buttons. Every command asks for confirmation before it is queued.
public struct CommandButtons: View {
    @ObservedObject var model: StatusModel
    @State private var pending: OperatorCommand?

    public init(model: StatusModel) { self.model = model }

    public var body: some View {
        let entryStopOn = model.response?.status?.entryStop ?? false
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(entryStopOn ? "Clear entry stop" : "Set entry stop") {
                    pending = .entryStop(on: !entryStopOn)
                }
                Button("Cancel own orders") { pending = .cancelOwnOrders }
                Button("Flatten", role: .destructive) { pending = .flatten }
            }
            .disabled(model.sending)
            if let message = model.lastCommandMessage {
                Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .confirmationDialog(
            pending.map(Self.question) ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { command in
            Button(Display.commandTitle(command.kind), role: command == .flatten ? .destructive : nil) {
                Task { await model.send(command) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { command in
            Text(Self.explanation(command))
        }
    }

    static func question(_ command: OperatorCommand) -> String {
        switch command {
        case .entryStop(on: true): return "Block new entries?"
        case .entryStop(on: false): return "Allow new entries again?"
        case .cancelOwnOrders: return "Cancel the bot's working entry orders?"
        case .flatten: return "Close the bot's position now?"
        }
    }

    static func explanation(_ command: OperatorCommand) -> String {
        switch command {
        case .entryStop(on: true):
            return "The bot will not open new positions until you clear the entry stop. "
                + "An open position and its stop stay as they are."
        case .entryStop(on: false):
            return "Clears only the operator entry stop. Other blocks (risk, reconciliation, session) still apply."
        case .cancelOwnOrders:
            return "Cancels the bot's own working entry orders. Protective stops are never cancelled."
        case .flatten:
            return "The bot closes its own position through the normal exit: cancel the stop, "
                + "confirm, re-read the quantity, then sell at market. Foreign positions are not touched."
        }
    }
}

/// The full status screen (window on macOS, a tab or screen on iOS later).
public struct StatusView: View {
    @ObservedObject var model: StatusModel

    public init(model: StatusModel) { self.model = model }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeadlineView(headline: model.headline)
                CommandButtons(model: model)
                if let status = model.response?.status {
                    BotSection(status: status, response: model.response!)
                    PositionSection(position: status.position)
                    if !status.fences.isEmpty { FencesSection(fences: status.fences) }
                    TradesSection(status: status)
                    CommandsSection(records: status.recentCommands)
                } else if let cause = model.response?.unavailableCause {
                    GroupBox("Bot") { Text(cause).frame(maxWidth: .infinity, alignment: .leading) }
                }
                Footer(response: model.response)
            }
            .padding()
        }
    }
}

struct BotSection: View {
    let status: StatusV1
    let response: StatusResponseV1

    var body: some View {
        GroupBox("Bot") {
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("State", value: status.botState.rawValue)
                LabeledContent("Environment", value: status.environment)
                LabeledContent("Trading gate",
                               value: "\(status.tradingGate.open ? "open" : "closed") (\(status.tradingGate.cause))")
                LabeledContent("Strategy", value: "\(status.strategy.name) v\(status.strategy.version)")
                LabeledContent("Entry stop", value: status.entryStop ? "ON (set by operator)" : "off")
                LabeledContent("Entry block",
                               value: status.entryBlock.map { "\($0.text) [\($0.cause)]" } ?? "none")
                LabeledContent("Quote stream", value: status.freshness.stream.rawValue)
                LabeledContent("Last broker read", value: Display.time(status.freshness.lastBrokerReadAt))
                LabeledContent("Last quote", value: Display.time(status.freshness.lastQuoteAt))
                LabeledContent("Status age",
                               value: (response.ageSeconds.map { "\($0.text) s" } ?? "—")
                                   + (response.stale ? " (stale)" : ""))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PositionSection: View {
    let position: Position?

    var body: some View {
        GroupBox("Position") {
            Group {
                if let position {
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Symbol", value: position.symbol)
                        LabeledContent("Quantity", value: position.quantity.text)
                        LabeledContent("Entry price", value: position.entryPrice.text)
                        LabeledContent("Opened", value: Display.time(position.openedAt))
                        LabeledContent("Stop") {
                            Text(position.stop.state.rawValue
                                 + (position.stop.price.map { " at \($0.text)" } ?? ""))
                                .foregroundStyle(position.stop.state == .verified ? Color.primary : Color.red)
                        }
                    }
                } else {
                    Text("None").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct FencesSection: View {
    let fences: [Fence]

    var body: some View {
        GroupBox("Fences") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(fences, id: \.self) { fence in
                    Text("\(fence.text) (\(fence.kind), since \(Display.time(fence.since)))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TradesSection: View {
    let status: StatusV1

    var body: some View {
        GroupBox("Today") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Result (gross): \(Display.usd(status.resultTodayGrossUsd)) over \(status.tradesToday.count) trade(s)")
                    .foregroundStyle(status.resultTodayGrossUsd.isNegative ? Color.red : Color.primary)
                ForEach(status.tradesToday, id: \.self) { trade in
                    Text("\(trade.symbol) \(trade.quantity.text) @ \(trade.entryPrice.text) → \(trade.exitPrice.text), "
                         + "\(trade.exitReason), \(Display.usd(trade.resultGrossUsd)) "
                         + "(\(Display.time(trade.openedAt))–\(Display.time(trade.closedAt)))")
                        .font(.callout.monospacedDigit())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CommandsSection: View {
    let records: [CommandRecord]

    var body: some View {
        GroupBox("Recent commands") {
            VStack(alignment: .leading, spacing: 4) {
                if records.isEmpty { Text("None").foregroundStyle(.secondary) }
                ForEach(records, id: \.self) { record in
                    Text("\(Display.commandTitle(record.kind)): \(record.outcome.rawValue)"
                         + (record.cause.map { " (\($0))" } ?? "")
                         + " at \(Display.time(record.processedAt))")
                        .font(.callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct Footer: View {
    let response: StatusResponseV1?

    var body: some View {
        Text(response.map { "Served \(Display.time($0.servedAt)) · refresh every \($0.pollSeconds.text) s" }
             ?? "Waiting for the first answer")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// Compact content for the macOS menu-bar popover.
public struct MenuContent: View {
    @ObservedObject var model: StatusModel
    let openWindow: () -> Void

    public init(model: StatusModel, openWindow: @escaping () -> Void) {
        self.model = model
        self.openWindow = openWindow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeadlineView(headline: model.headline)
            if let status = model.response?.status {
                if let position = status.position {
                    Text("\(position.symbol) \(position.quantity.text) @ \(position.entryPrice.text), "
                         + "stop \(position.stop.state.rawValue)"
                         + (position.stop.price.map { " \($0.text)" } ?? ""))
                } else {
                    Text("No position").foregroundStyle(.secondary)
                }
                Text("Today: \(Display.usd(status.resultTodayGrossUsd)) · stream \(status.freshness.stream.rawValue)"
                     + " · age \(model.response?.ageSeconds?.text ?? "—") s")
                    .font(.callout)
            }
            CommandButtons(model: model)
            Divider()
            HStack {
                Button("Open window", action: openWindow)
                Spacer()
                Button("Quit") { quitApp() }
            }
        }
        .padding()
        .frame(width: 380)
    }
}

func quitApp() {
    #if os(macOS)
    NSApplication.shared.terminate(nil)
    #endif
}
