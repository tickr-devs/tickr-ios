import ApertureDesign
import ApertureKit
import SwiftUI

/// The first screen: the day's result, the one line that says what the bot is doing, live events,
/// open positions and the health of the bot's inputs. The power button opens bot control.
struct HomeView: View {
  @Environment(AppModel.self) private var model
  @State private var showControl = false

  var body: some View {
    Screen("Aperture") {
      ConnectionPrompt()
      DayLine().rise(0.05)
      Summary().rise(0.1)
      if let status = model.status {
        let events = Board.events(status)
        if !events.isEmpty {
          Ticker(events.map { TickerItem(id: $0.id, tag: $0.tag, text: $0.text, tone: $0.tone.ticker) },
            moving: model.response?.stale == false)
            .padding(.vertical, 8)
            .background(Palette.deep, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
            .rise(0.15)
        }
        ForEach(Array(Board.positions(status).enumerated()), id: \.element.symbol) { index, position in
          PositionRow(position: position)
            .rise(0.2 + Double(index) * 0.06)
        }
        if status.position == nil {
          Text("No open position.")
            .font(.subheadline)
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .apertureCard()
            .rise(0.2)
        }
        HealthCard(status: status).rise(0.3)
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        if let environment = model.status?.environment {
          EnvironmentBadge(environment: environment)
        }
        Button {
          showControl = true
        } label: {
          Image(systemName: "power")
            .fontWeight(.semibold)
            .foregroundStyle(model.canCommand ? Palette.amberStrong : Palette.dim)
        }
        .disabled(!model.canCommand)
        .accessibilityLabel("Bot control")
        NavigationLink {
          SettingsView()
        } label: {
          Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings")
      }
    }
    .botControl(isPresented: $showControl)
    .refreshable { await model.refresh() }
  }
}

/// The trading day being shown. Past days arrive with the days API; until then this is today only.
private struct DayLine: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    HStack(spacing: 6) {
      if model.response?.stale == false {
        PulseDot(Palette.green, size: 6)
      }
      Text((model.status?.writtenAt.date ?? .now).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
      Text("· today")
      Spacer()
      Text(Format.age(model.response))
        .contentTransition(.numericText())
    }
    .font(.system(size: 12, design: .monospaced))
    .foregroundStyle(Palette.dim)
  }
}

/// The ring with the day's result next to the headline.
private struct Summary: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let stats = model.status.map(Board.dayStats)
    let result = stats?.resultGrossUsd ?? 0
    let headline = model.headline
    HStack(spacing: 16) {
      ResultRing(fraction: stats?.winShare ?? 0, color: result < 0 ? Palette.pink : Palette.teal) {
        VStack(spacing: 2) {
          CardLabel("day")
          Text(Money.signed(result))
            .font(.system(size: 22, weight: .bold, design: .monospaced))
            .foregroundStyle(result < 0 ? Palette.pinkStrong : Palette.greenStrong)
            .contentTransition(.numericText(value: NSDecimalNumber(decimal: result).doubleValue))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
          Text(stats.map { "\($0.wins) W · \($0.losses) L" } ?? "—")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Palette.dim)
        }
        .padding(18)
      }
      .frame(width: 136, height: 136)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Day result \(Money.signedUSD(result)), \(stats?.wins ?? 0) wins, \(stats?.losses ?? 0) losses")

      VStack(alignment: .leading, spacing: 7) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          PulseDot(headline.severity.tint, pulsing: headline.severity != .ok || model.response?.stale == false)
          Text(headline.text)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(headline.severity.tint)
            .fixedSize(horizontal: false, vertical: true)
        }
        if let status = model.status {
          Text(subline(status))
            .font(.system(size: 12.5))
            .foregroundStyle(Palette.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .animation(.default, value: headline)
    }
  }

  private func subline(_ status: StatusV1) -> String {
    var parts: [String] = []
    if let position = status.position {
      parts.append(position.stop.state.isProtected
        ? "\(position.symbol) protected by a broker stop."
        : "\(position.symbol) stop is \(position.stop.state.rawValue).")
    }
    parts.append("Strategy \(status.strategy.name) v\(status.strategy.version).")
    if !status.tradingGate.open { parts.append("Trading gate closed: \(status.tradingGate.cause).") }
    return parts.joined(separator: " ")
  }
}

/// One open position on Home; tapping it opens it on the Positions tab.
private struct PositionRow: View {
  @Environment(AppModel.self) private var model
  let position: Position

  var body: some View {
    Button {
      model.selectedSymbol = position.symbol
      model.selectedTab = .positions
    } label: {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(position.symbol)
            .font(.system(size: 17, weight: .bold, design: .monospaced))
            .foregroundStyle(Palette.text)
          Text(stopLine)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(position.stop.state.isProtected ? Palette.greenStrong : Palette.redStrong)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 3) {
          Text("\(position.quantity.text) @ \(position.entryPrice.text)")
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundStyle(Palette.text)
          Text("since \(Format.time(position.openedAt.date))")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Palette.dim)
        }
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Palette.dim)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 11)
      .apertureCard(tint: position.stop.state.isProtected ? nil : Palette.red)
    }
    .buttonStyle(.plain)
  }

  private var stopLine: String {
    switch position.stop.state {
    case .verified: return "stop \u{2713} \(position.stop.price?.text ?? "")"
    case .pending: return "stop pending"
    case .missing: return "NO STOP"
    case .unknown: return "stop unknown"
    }
  }
}

/// The bot's inputs at a glance: broker reads, quote stream, gate, and outstanding fences.
private struct HealthCard: View {
  let status: StatusV1

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        CardLabel("Bot inputs")
        Spacer()
        Text(status.botState.rawValue)
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(status.botState == .running ? Palette.greenStrong : Palette.amberStrong)
      }
      HStack(alignment: .top) {
        item("broker", Format.timeOrDash(status.freshness.lastBrokerReadAt), status.freshness.lastBrokerReadAt != nil ? Palette.blue : Palette.red)
        Spacer()
        item("quotes", status.freshness.stream.rawValue, streamColor)
        Spacer()
        item("gate", status.tradingGate.open ? "open" : "closed", status.tradingGate.open ? Palette.green : Palette.amber)
        Spacer()
        item("entries", status.entryBlock == nil ? "allowed" : "blocked", status.entryBlock == nil ? Palette.teal : Palette.amber)
      }
      ForEach(status.fences, id: \.kind) { fence in
        Label(fence.text, systemImage: "exclamationmark.triangle.fill")
          .font(.system(size: 12))
          .foregroundStyle(Palette.amberStrong)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .apertureCard()
  }

  private var streamColor: Color {
    switch status.freshness.stream {
    case .fresh: return Palette.green
    case .quiet: return Palette.amber
    case .lost: return Palette.red
    case .off: return Palette.dim
    }
  }

  private func item(_ name: String, _ value: String, _ color: Color) -> some View {
    VStack(spacing: 5) {
      PulseDot(color, size: 10, pulsing: color != Palette.dim)
        .shadow(color: color, radius: 6)
      Text(name).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
      Text(value).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.text)
    }
    .accessibilityElement(children: .combine)
  }
}
