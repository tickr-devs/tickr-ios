import ApertureDesign
import ApertureKit
import SwiftUI

/// Overview: what the bot is doing now, its positions and protection, the day's result, and the
/// bot controls. For a recorded day it shows that day read-only.
struct OverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    HeaderCard().rise(0)
                    DayResultCard().frame(width: 300).rise(0.05)
                }
                LiveFlowCard().rise(0.1)
                HStack(alignment: .top, spacing: 16) {
                    PositionsCard().rise(0.15)
                    VStack(spacing: 16) {
                        SafetyCard()
                        BotCard()
                    }
                    .frame(width: 320)
                    .rise(0.2)
                    VStack(spacing: 16) {
                        RiskRoomCard()
                        ObserversCard()
                        JournalCard()
                    }
                    .frame(width: 320)
                    .rise(0.25)
                }
            }
            .padding(20)
            .frame(maxWidth: 1500)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: header

private struct HeaderCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            ApertureLogo(size: 60)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Aperture").font(.system(size: 26, weight: .bold))
                    Text("Operator").font(.system(size: 18, weight: .medium, design: .monospaced)).foregroundStyle(Palette.dim)
                    if let status = model.status {
                        Badge(text: status.environment.uppercased(), color: Palette.violetStrong)
                        Badge(text: status.tradingGate.open ? "GATE OPEN" : "GATE CLOSED",
                              color: status.tradingGate.open ? Palette.tealStrong : Palette.amberStrong)
                            .help(status.tradingGate.cause)
                    }
                }
                banner
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .apertureCard()
    }

    private var banner: some View {
        let (title, detail, color, alarm) = content
        return HStack(spacing: 10) {
            PulseDot(color, size: 9, pulsing: model.isLive)
            Text(title).font(.headline).foregroundStyle(color)
            if let detail { Text(detail).font(.callout).foregroundStyle(Palette.muted).lineLimit(2) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(color.opacity(0.4)))
        .modifier(AlarmPulse(active: alarm))
        .textSelection(.enabled)
    }

    private var content: (String, String?, Color, Bool) {
        if !model.isLive {
            return ("Recorded day · \(Format.dayLabel(model.shownDay))",
                    "Read-only view from the bot's records. Commands are off.", Palette.violetStrong, false)
        }
        let headline = model.headline
        var detail: String?
        if let status = model.status, model.fetchError == nil, model.response?.stale == false {
            let count = Board.positions(status).count
            if count > 0 {
                let protected = Board.positions(status).filter { $0.stop.state == .verified }.count
                detail = "\(count) position\(count == 1 ? "" : "s") · \(protected) protected by a verified broker stop"
            } else {
                detail = "No open position."
            }
        }
        return (headline.text, detail, headline.severity.color, headline.severity == .alarm)
    }
}

/// A soft red glow that breathes around something that needs attention now.
struct AlarmPulse: ViewModifier {
    let active: Bool
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .shadow(color: active ? Palette.red.opacity(on ? 0.55 : 0.1) : .clear, radius: on ? 10 : 2)
            .onAppear {
                guard active, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { on = true }
            }
            .onChange(of: active) { _, now in
                on = false
                if now && !reduceMotion {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { on = true }
                }
            }
    }
}

private struct DayResultCard: View {
    @Environment(AppModel.self) private var model
    @State private var counted: Decimal = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardLabel("Day result · gross")
            MoneyText(value: counted, usd: true, size: 34, weight: .bold)
            Text(subtitle).font(.caption.monospaced()).foregroundStyle(Palette.dim)
            DrawnSparkline(values: model.cumulativeResults, color: Palette.result(model.shownResult))
                .frame(height: 34)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .apertureCard()
        .onAppear { countUp() }
        .onChange(of: model.shownResult) { countUp() }
    }

    private var subtitle: String {
        var text = "\(model.shownTradeCount) closed · \(model.shownWins) W · \(model.shownLosses) L"
        let unrealized = model.positions.compactMap(\.unrealized)
        // Only when every open position has a fresh price; a partial sum would mislead.
        if model.isLive && !model.positions.isEmpty && unrealized.count == model.positions.count {
            text += " · open " + Money.signed(unrealized.reduce(0, +))
        }
        return text
    }

    private func countUp() {
        withAnimation(.spring(response: 1.1, dampingFraction: 0.9)) { counted = model.shownResult }
    }
}

// MARK: live flow

private struct LiveFlowCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card(title: "Live flow · screeners → strategy → risk → order → broker stop") {
            Text(model.isLive ? "live" : "recorded").font(.caption.monospaced()).foregroundStyle(Palette.dim)
        } content: {
            Ticker(tickerItems, moving: model.isLive)
                .frame(height: 22)
            Pipeline(stages: stages, moving: model.isLive)
                .frame(height: 96)
        }
    }

    private var tickerItems: [TickerItem] {
        guard let status = model.status, model.isLive else {
            return model.shownTrades.map {
                TickerItem(id: $0.tradeId, tag: $0.exitReason.uppercased(),
                           text: "\($0.symbol) \(Money.signed($0.resultGrossUsd.value))",
                           tone: $0.resultGrossUsd.value >= 0 ? .green : .red)
            }
        }
        let events = Board.events(status)
        if events.isEmpty {
            return [TickerItem(id: "quiet", tag: "QUIET", text: "nothing recorded yet today", tone: .muted)]
        }
        return events.map { TickerItem(id: $0.id, tag: $0.tag, text: $0.text, tone: $0.tone.tickerTone) }
    }

    private var stages: [Pipeline.Stage] {
        let status = model.isLive ? model.status : nil
        let position = status.flatMap { Board.positions($0).first }
        return [
            .init(name: "SCREENERS", value: nil, symbol: "magnifyingglass", color: Palette.teal),
            .init(name: "UNIVERSE", value: nil, symbol: "line.3.horizontal.decrease", color: Palette.pink),
            .init(name: "STRATEGY", value: status.map { "\($0.strategy.name) v\($0.strategy.version)" },
                  symbol: "chart.bar", color: Palette.violet),
            .init(name: "RISK", value: status.map { $0.entryBlock == nil ? "entries allowed" : "blocked" },
                  symbol: "shield", color: Palette.amber),
            .init(name: "ORDER", value: status.map { "\($0.tradesToday.count) closed" }, symbol: "bolt", color: Palette.blue),
            .init(name: "BROKER STOP", value: status.map { _ in position.map { Board.stopTag($0.stop.state) } ?? "no position" },
                  symbol: "lock", color: position.map { $0.stop.state == .verified ? Palette.green : Palette.red } ?? Palette.green),
            .init(name: "RECONCILE", value: status.map { $0.fences.isEmpty ? "match" : "\($0.fences.count) fence(s)" },
                  symbol: "arrow.triangle.2.circlepath", color: Palette.blue),
        ]
    }
}

extension Board.Event.Tone {
    var tickerTone: TickerItem.Tone {
        switch self {
        case .teal: return .teal
        case .green: return .green
        case .blue: return .blue
        case .amber: return .amber
        case .violet: return .violet
        case .red: return .red
        case .muted: return .muted
        }
    }

    var color: Color {
        switch self {
        case .teal: return Palette.tealStrong
        case .green: return Palette.greenStrong
        case .blue: return Palette.blueStrong
        case .amber: return Palette.amberStrong
        case .violet: return Palette.violetStrong
        case .red: return Palette.redStrong
        case .muted: return Palette.muted
        }
    }
}

/// The stages a setup passes through, with light travelling along the line between them.
private struct Pipeline: View {
    struct Stage: Identifiable {
        let name: String
        /// nil = the API does not report this stage yet.
        let value: String?
        let symbol: String
        let color: Color
        var id: String { name }
    }

    let stages: [Stage]
    let moving: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let inset = proxy.size.width / CGFloat(stages.count) / 2
                let width = proxy.size.width - 2 * inset
                Capsule().fill(Palette.line).frame(width: width, height: 2).offset(x: inset, y: 21)
                if moving && !reduceMotion {
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        ForEach(0..<3, id: \.self) { index in
                            let phase = ((t / 4.2) + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                            Circle()
                                .fill(Palette.teal)
                                .frame(width: 8, height: 8)
                                .shadow(color: Palette.teal.opacity(0.7), radius: 6)
                                .opacity(phase < 0.08 ? phase / 0.08 : phase > 0.92 ? (1 - phase) / 0.08 : 1)
                                .offset(x: inset + width * phase - 4, y: 18)
                        }
                    }
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(Palette.card)
                            Circle().strokeBorder(stage.color.opacity(stage.value == nil ? 0.35 : 1), lineWidth: 1.5)
                            Image(systemName: stage.symbol).font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(stage.color.opacity(stage.value == nil ? 0.45 : 1))
                        }
                        .frame(width: 44, height: 44)
                        .overlay {
                            if stage.value != nil && moving {
                                PulseDot(stage.color, size: 44, pulsing: true).opacity(0.25)
                                    .animation(.default.delay(Double(index) * 0.35), value: moving)
                            }
                        }
                        Text(stage.name).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.text2)
                        if let value = stage.value {
                            Text(value).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Palette.muted)
                                .lineLimit(1).contentTransition(.numericText())
                        } else {
                            Text("—").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Palette.dim)
                                .help("Not reported by the local API yet.")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: positions

private struct PositionsCard: View {
    @Environment(AppModel.self) private var model
    @State private var selected: String?

    var body: some View {
        let rows = model.positions
        let maxPositions = model.settings?.risk.maxOpenPositions
        Card(title: "Positions \(rows.count)" + (maxPositions.map { " of \($0)" } ?? "")) {
            Button("Open Chart") { model.section = .chart }
                .buttonStyle(.link)
                .disabled(rows.isEmpty)
        } content: {
            if rows.count > 1 {
                Picker("Position", selection: Binding(get: { selected ?? rows.first?.id }, set: { selected = $0 })) {
                    ForEach(rows) { row in Text(row.position.symbol).tag(Optional(row.id)) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            if let row = rows.first(where: { $0.id == selected }) ?? rows.first {
                PositionDetail(row: row)
                    .id(row.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                EmptyPositions()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: selected)
    }
}

private struct PositionDetail: View {
    let row: PositionRow

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            MiniChart(closes: row.closes, entry: row.entry, stop: row.stop)
                .frame(minWidth: 260, minHeight: 210)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(row.position.symbol).font(.system(size: 28, weight: .bold, design: .monospaced))
                    Spacer()
                    StopBadge(state: row.position.stop.state)
                }
                VStack(spacing: 6) {
                    StatLine(label: "quantity", value: Format.quantity(row.quantity))
                    StatLine(label: "entry", value: Format.price(row.entry))
                    StatLine(label: "last bar close" + (row.lastBarAt.map { " · " + Format.marketMinute($0) } ?? ""),
                             value: row.lastBarClose.map { Format.price($0) } ?? (row.lastBarAt == nil ? "—" : "old"))
                    StatLine(label: "stop", value: Format.price(row.stop),
                             color: row.position.stop.state == .verified ? Palette.greenStrong : Palette.redStrong)
                    StatLine(label: "max loss", value: Risk.plannedLoss(entry: row.entry, stop: row.stop, quantity: row.quantity)
                        .map { Money.plain($0) } ?? "—")
                    StatLine(label: "R now", value: row.resultR.map(Risk.text) ?? "—")
                    StatLine(label: "opened", value: Format.marketTime(row.position.openedAt.date))
                }
                Divider()
                HStack {
                    Text("unrealized").font(.callout).foregroundStyle(Palette.muted)
                    Spacer()
                    if let value = row.unrealized { MoneyText(value: value, size: 22, weight: .bold) } else { Text("—") }
                }
            }
            .frame(width: 250)
        }
    }
}

struct StopBadge: View {
    let state: StopState

    var body: some View {
        Badge(text: Board.stopTag(state), color: state == .verified ? Palette.greenStrong : Palette.redStrong)
            .modifier(AlarmPulse(active: state != .verified))
    }
}

/// Closes since the entry, with the entry and stop as dashed lines and a pulsing last point.
private struct MiniChart: View {
    let closes: [Decimal]
    let entry: Decimal
    let stop: Decimal?
    @State private var drawn: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            chart(size: proxy.size)
        }
        .padding(8)
        .background(Palette.deep, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { withAnimation(.easeOut(duration: 1.6)) { drawn = 1 } }
        .accessibilityLabel("Price since entry with entry and stop lines")
    }

    /// Maps a price to a y coordinate, with some room above and below every value shown.
    private struct Scale {
        let low: Double
        let high: Double
        let height: CGFloat

        init(values: [Double], height: CGFloat) {
            let lowest = values.min() ?? 0
            let highest = values.max() ?? 1
            let pad = max((highest - lowest) * 0.12, 0.01)
            low = lowest - pad
            high = highest + pad
            self.height = height
        }

        func y(_ value: Double) -> CGFloat {
            let fraction = (value - low) / (high - low)
            return height * CGFloat(1 - fraction)
        }
    }

    @ViewBuilder private func chart(size: CGSize) -> some View {
        let values: [Double] = closes.map(Self.double)
        let entryValue = Self.double(entry)
        let stopValue: Double? = stop.map(Self.double)
        let scale = Scale(values: values + [entryValue] + (stopValue.map { [$0] } ?? []), height: size.height)
        ZStack(alignment: .topLeading) {
            level(scale.y(entryValue), width: size.width, color: Palette.blue, label: "entry \(Money.plain(entry))")
            if let stop, let stopValue {
                level(scale.y(stopValue), width: size.width, color: Palette.red, label: "stop \(Money.plain(stop))")
            }
            if values.count > 1 {
                line(values: values, scale: scale, width: size.width)
                    .trim(from: 0, to: drawn)
                    .stroke(Palette.teal, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                PulseDot(Palette.teal, size: 8)
                    .position(x: size.width, y: scale.y(values[values.count - 1]))
            } else {
                Text("Waiting for the first bars since the entry")
                    .font(.caption).foregroundStyle(Palette.dim)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func line(values: [Double], scale: Scale, width: CGFloat) -> Path {
        var path = Path()
        let step = width / CGFloat(values.count - 1)
        for (index, value) in values.enumerated() {
            let point = CGPoint(x: step * CGFloat(index), y: scale.y(value))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    private func level(_ y: CGFloat, width: CGFloat, color: Color, label: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: width, y: y)) }
                .stroke(color.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
            Text(label).font(.system(size: 10, design: .monospaced)).foregroundStyle(color)
                .offset(y: y - 15)
        }
    }

    static func double(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
}

private struct EmptyPositions: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 20) {
            Radar().frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 6) {
                Text(model.isLive ? "No position" : "Recorded day").font(.title3.weight(.semibold))
                Text(model.isLive
                     ? "The bot is waiting for a setup. A new position appears here with its broker stop."
                     : "\(model.shownTradeCount) trades closed this day. Details are in Trades & days.")
                    .font(.callout).foregroundStyle(Palette.muted)
                if !model.isLive {
                    Button("Open Trades & days") { model.section = .trades }.buttonStyle(.link)
                }
            }
            Spacer()
        }
        .frame(minHeight: 200)
    }
}

/// A slow radar sweep while the bot scans for setups.
private struct Radar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let angle = Angle.degrees(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4 * 360)
            ZStack {
                ForEach([1.0, 0.66, 0.33], id: \.self) { scale in
                    Circle().stroke(Palette.line2, lineWidth: 1).scaleEffect(scale)
                }
                AngularGradient(colors: [Palette.teal.opacity(0.45), .clear], center: .center,
                                startAngle: .degrees(0), endAngle: .degrees(90))
                    .clipShape(Circle())
                    .rotationEffect(angle)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: safety and bot

private struct SafetyCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card("Safety") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 8) {
                    ForEach(rows(now: context.date), id: \.label) { row in
                        HStack(spacing: 8) {
                            Circle().fill(row.color).frame(width: 7, height: 7)
                            Text(row.label).font(.callout).foregroundStyle(Palette.muted)
                            Spacer()
                            Text(row.value).font(.callout.monospaced()).foregroundStyle(row.color)
                                .lineLimit(1).contentTransition(.numericText())
                        }
                    }
                }
            }
        }
    }

    private struct Row { let label: String; let value: String; let color: Color }

    private func rows(now: Date) -> [Row] {
        guard model.isLive, let status = model.status else {
            return [Row(label: "Status", value: model.isLive ? "unavailable" : "recorded day", color: Palette.dim)]
        }
        let positions = Board.positions(status)
        let verified = positions.filter { $0.stop.state == .verified }.count
        let foreign = status.fences.first { $0.kind == "foreign_exposure" }
        return [
            Row(label: "Broker stops", value: positions.isEmpty ? "no position" : "\(verified) of \(positions.count) verified",
                color: verified == positions.count ? Palette.greenStrong : Palette.redStrong),
            Row(label: "Reconciliation", value: status.fences.isEmpty ? "no fences" : "\(status.fences.count) fence(s)",
                color: status.fences.isEmpty ? Palette.greenStrong : Palette.amberStrong),
            Row(label: "Quote stream", value: status.freshness.stream.rawValue,
                color: status.freshness.stream == .fresh ? Palette.greenStrong
                    : status.freshness.stream == .off ? Palette.dim : Palette.amberStrong),
            Row(label: "Last broker read", value: Format.age(since: status.freshness.lastBrokerReadAt?.date, now: now),
                color: Palette.greenStrong),
            Row(label: "Foreign positions", value: foreign == nil ? "none" : "present",
                color: foreign == nil ? Palette.greenStrong : Palette.redStrong),
            Row(label: "Entry pause", value: status.entryStop ? "on" : "off",
                color: status.entryStop ? Palette.amberStrong : Palette.dim),
        ]
    }
}

private struct BotCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card(title: "Bot") {
            if let status = model.status {
                HStack(spacing: 6) {
                    PulseDot(status.botState == .running ? Palette.teal : Palette.dim, size: 7,
                             pulsing: status.botState == .running && model.isLive)
                    Text(status.entryStop ? "entries paused" : status.botState.rawValue)
                        .font(.caption.monospaced()).foregroundStyle(Palette.muted)
                }
            }
        } content: {
            BotControls()
            if !model.isLive {
                Text("Commands are off while a recorded day is shown.").font(.caption).foregroundStyle(Palette.dim)
            } else if model.response?.stale == true || model.fetchError != nil {
                Text("Commands are off while the status cannot be trusted.").font(.caption).foregroundStyle(Palette.redStrong)
            }
        }
    }
}

// MARK: right column

private struct RiskRoomCard: View {
    @Environment(AppModel.self) private var model
    @State private var shown: Double = 0

    var body: some View {
        Card(title: "Risk room today") {
            Button("Details") { model.section = .risk }.buttonStyle(.link)
        } content: {
            if let risk = model.settings?.risk {
                let limit = risk.maxDailyLossUsd.value
                let room = max(0, limit + min(model.shownResult, 0))
                let fraction = limit > 0 ? NSDecimalNumber(decimal: room / limit).doubleValue : 0
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    MoneyText(value: room, size: 24, weight: .bold, colored: false)
                    Text("of \(Money.plain(limit)) USD left").font(.callout).foregroundStyle(Palette.muted)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.line)
                        Capsule()
                            .fill(LinearGradient(colors: [Palette.red, Palette.amber, Palette.teal], startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * shown)
                    }
                }
                .frame(height: 8)
                .onAppear { withAnimation(.spring(response: 1.2, dampingFraction: 0.9)) { shown = fraction } }
                .onChange(of: fraction) { _, value in withAnimation(.spring) { shown = value } }
                VStack(spacing: 6) {
                    StatLine(label: "net day result", value: Money.signed(model.shownResult), color: Palette.result(model.shownResult))
                    StatLine(label: "positions", value: "\(model.positions.count) of \(risk.maxOpenPositions)")
                    StatLine(label: "planned loss / trade", value: Money.plain(risk.plannedLossUsd.value))
                    StatLine(label: "notional cap", value: Money.plain(risk.positionNotionalCapUsd.value))
                    HStack {
                        Text("open reservations").font(.callout).foregroundStyle(Palette.muted)
                        Spacer()
                        PlannedTag(.needsAPI)
                    }
                }
            } else {
                Text(model.settingsError ?? "Reading limits…").font(.caption).foregroundStyle(Palette.dim)
            }
        }
    }
}

private struct ObserversCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card(title: "Observers · shadow") {
            PlannedTag()
        } content: {
            let observers = model.settings?.observers ?? []
            if observers.isEmpty {
                Text("No observer strategies configured.").font(.callout).foregroundStyle(Palette.muted)
            } else {
                ForEach(observers, id: \.self) { name in
                    HStack {
                        PulseDot(Palette.violet, size: 6, pulsing: model.isLive)
                        Text(name).font(.callout.monospaced())
                        Spacer()
                        Text("—").foregroundStyle(Palette.dim).help("Observer results are not in the local API yet.")
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Palette.violetStrong)
                Text("AI advisor proposals").font(.callout)
                Spacer()
                PlannedTag()
            }
        }
    }
}

private struct JournalCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card(title: "Journal") {
            Text("latest first").font(.caption.monospaced()).foregroundStyle(Palette.dim)
        } content: {
            let events = model.isLive ? (model.status.map(Board.events) ?? []) : []
            if events.isEmpty {
                Text(model.isLive ? "Nothing recorded yet today." : "See Trades & days for this day.")
                    .font(.callout).foregroundStyle(Palette.muted)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events.prefix(10)) { event in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(Format.marketTime(event.time)).foregroundStyle(Palette.dim)
                            Text(event.tag).fontWeight(.bold).foregroundStyle(event.tone.color)
                            Text(event.text).foregroundStyle(Palette.text2).lineLimit(1)
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: events.map(\.id))
                .textSelection(.enabled)
            }
        }
    }
}
