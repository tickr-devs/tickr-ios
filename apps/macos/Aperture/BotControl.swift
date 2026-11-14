import ApertureDesign
import ApertureKit
import SwiftUI

/// An operator action as the app offers it. Each maps to one local-API command, or is shown
/// disabled when the API has no command for it yet.
enum BotAction: Identifiable, Equatable {
    case pauseEntries, resumeEntries, cancelOrders, flatten(symbol: String), flattenAll, stopBot

    var id: String {
        switch self {
        case .pauseEntries: return "pause"
        case .resumeEntries: return "resume"
        case .cancelOrders: return "cancel"
        case .flatten(let symbol): return "flatten-\(symbol)"
        case .flattenAll: return "flatten-all"
        case .stopBot: return "stop"
        }
    }

    /// The API command, nil when there is none yet.
    var command: OperatorCommand? {
        switch self {
        case .pauseEntries: return .entryStop(on: true)
        case .resumeEntries: return .entryStop(on: false)
        case .cancelOrders: return .cancelOwnOrders
        // v1 holds at most one position, and the flatten command closes the bot's own position.
        case .flatten, .flattenAll: return .flatten
        case .stopBot: return nil
        }
    }

    var title: String {
        switch self {
        case .pauseEntries: return "Pause Entries"
        case .resumeEntries: return "Resume Entries"
        case .cancelOrders: return "Cancel Orders"
        case .flatten(let symbol): return "Flatten \(symbol)"
        case .flattenAll: return "Flatten All"
        case .stopBot: return "Stop Bot"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .flatten, .flattenAll, .stopBot: return true
        default: return false
        }
    }

    /// Pausing and resuming are reversible and act at once; the rest ask first.
    var needsConfirmation: Bool {
        switch self {
        case .pauseEntries, .resumeEntries: return false
        default: return true
        }
    }

    var question: String {
        switch self {
        case .pauseEntries: return "Pause new entries?"
        case .resumeEntries: return "Resume new entries?"
        case .cancelOrders: return "Cancel the bot's working entry orders?"
        case .flatten(let symbol): return "Flatten \(symbol)?"
        case .flattenAll: return "Flatten all positions?"
        case .stopBot: return "Stop the bot?"
        }
    }

    var explanation: String {
        switch self {
        case .pauseEntries:
            return "The bot opens no new positions until you resume. Open positions keep their broker stops."
        case .resumeEntries:
            return "Clears only your entry pause. Other blocks (risk, reconciliation, session) still apply."
        case .cancelOrders:
            return "Cancels the bot's own working entry orders. Protective stops are never cancelled."
        case .flatten:
            return "The bot cancels the stop, reads the held quantity again and sells it through the normal exit. "
                + "The result appears in Trades & days."
        case .flattenAll:
            return "Every own position closes through the normal exit. Positions the bot did not open are not touched."
        case .stopBot:
            return "Needs a new API command: new entries blocked, working entries cancelled, broker stops left resting."
        }
    }
}

/// The bot control buttons with standard confirmation alerts. Used on Overview and in the menu bar.
struct BotControls: View {
    @Environment(AppModel.self) private var model
    @State private var confirming: BotAction?
    var compact = false

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: compact ? 3 : 2)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(actions) { action in
                Button(role: action.isDestructive ? .destructive : nil) {
                    if action.needsConfirmation { confirming = action } else { run(action) }
                } label: {
                    HStack(spacing: 4) {
                        Text(action.title + (action.needsConfirmation ? "…" : ""))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if action.command == nil { PlannedTag(.needsAPI) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(compact ? .regular : .large)
                .tint(action.isDestructive ? Palette.red : nil)
                .disabled(action.command == nil || !model.commandsEnabled || !applicable(action))
                .help(action.explanation)
            }
        }
        .alert(confirming?.question ?? "", isPresented: Binding(get: { confirming != nil },
                                                                 set: { if !$0 { confirming = nil } }),
               presenting: confirming) { action in
            Button(action.title, role: action.isDestructive ? .destructive : nil) { run(action) }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.explanation)
        }
        // Close an open confirmation as soon as commands are no longer safe to send.
        .onChange(of: model.commandsEnabled) { _, enabled in
            if !enabled { confirming = nil }
        }
    }

    private var actions: [BotAction] {
        let paused = model.status?.entryStop ?? false
        var list: [BotAction] = [paused ? .resumeEntries : .pauseEntries, .cancelOrders]
        if compact {
            list.append(.flattenAll)
        } else {
            list += model.positions.map { .flatten(symbol: $0.position.symbol) }
            list += [.flattenAll, .stopBot]
        }
        return list
    }

    private func applicable(_ action: BotAction) -> Bool {
        switch action {
        case .flatten, .flattenAll: return !model.positions.isEmpty
        default: return true
        }
    }

    private func run(_ action: BotAction) {
        guard let command = action.command else { return }
        Task { await model.send(command, title: action.title) }
    }
}
