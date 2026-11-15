import ApertureDesign
import ApertureKit
import SwiftUI

/// Sidebar sections, ordered by how often they are used during a trading day.
enum AppSection: String, CaseIterable, Identifiable {
  case overview, chart, trades, risk, lab

  var id: String { rawValue }

  var title: LocalizedStringResource {
    switch self {
    case .overview: return L10n.Section.overview
    case .chart: return L10n.Section.chart
    case .trades: return L10n.Section.trades
    case .risk: return L10n.Section.risk
    case .lab: return L10n.Section.lab
    }
  }

  /// SF Symbols of the sections in the sidebar.
  static let overviewSymbol = "square.grid.2x2"
  static let chartSymbol = "chart.xyaxis.line"
  static let tradesSymbol = "list.bullet.rectangle"
  static let riskSymbol = "shield.lefthalf.filled"
  static let labSymbol = "sparkles"

  /// Accessibility ids of a section's sidebar row and its screen (the UI tests find them by these).
  static let rowIDPrefix = "sidebar-"
  static let screenIDPrefix = "screen-"
  var rowID: String { Self.rowIDPrefix + rawValue }
  var screenID: String { Self.screenIDPrefix + rawValue }

  var symbol: String {
    switch self {
    case .overview: return Self.overviewSymbol
    case .chart: return Self.chartSymbol
    case .trades: return Self.tradesSymbol
    case .risk: return Self.riskSymbol
    case .lab: return Self.labSymbol
    }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var model

  /// Sidebar width: least, preferred and most, in points.
  static let sidebarMin: CGFloat = 200
  static let sidebarIdeal: CGFloat = 220
  static let sidebarMax: CGFloat = 260

  private var section: AppSection { model.section }

  var body: some View {
    @Bindable var model = model
    NavigationSplitView {
      Sidebar(selection: $model.section)
        .navigationSplitViewColumnWidth(min: Self.sidebarMin, ideal: Self.sidebarIdeal, max: Self.sidebarMax)
    } detail: {
      ZStack(alignment: .bottom) {
        ApertureBackground()
        detail
          .safeAreaInset(edge: .top, spacing: 0) {
            if section != .overview { EventStrip() }
          }
          // One container element per screen, so its id holds even when the screen's root is a
          // split (the Chart's inspector) rather than a single view.
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier(section.screenID)
          .id(section)
          .transition(.opacity.combined(with: .move(edge: .bottom)))
        if let unattended = model.unattendedPositions {
          UnattendedBanner(unattended: unattended)
            .padding(Tokens.Space.l)
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        if let toast = model.toast {
          CommandToast(command: toast)
            .padding(.bottom, Tokens.Space.xl)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .animation(Tokens.Motion.standard, value: section)
      .animation(Tokens.Motion.standard, value: model.toast)
      .animation(Tokens.Motion.standard, value: model.unattendedPositions)
      .navigationTitle(Text(section.title))
      .navigationSubtitle(Text(verbatim: subtitle))
      .toolbar { DayToolbar() }
    }
  }

  @ViewBuilder private var detail: some View {
    switch section {
    case .overview: OverviewView()
    case .chart: ChartView()
    case .trades: TradesView()
    case .risk: RiskView()
    case .lab: LabView()
    }
  }

  /// "sandbox · price-action-v1 v1 · positions: 1", as in the design's title bar; the day is in
  /// the toolbar's day picker. Before the first status, the day.
  private var subtitle: String {
    guard let status = model.status else {
      return model.isLive
        ? String(localized: L10n.Common.todayDay(Format.dayLabel(model.today)))
        : String(localized: L10n.Common.recordedDay(Format.dayLabel(model.shownDay)))
    }
    let positions = String(localized: L10n.Toolbar.positions(status.positions.count))
    return "\(status.environment) · \(Format.strategy(status.strategy)) · \(positions)"
  }
}

/// The sidebar list plus the bot's state at the bottom.
private struct Sidebar: View {
  @Environment(AppModel.self) private var model
  @Binding var selection: AppSection

  var body: some View {
    List(selection: Binding(get: { selection }, set: { if let value = $0 { selection = value } })) {
      Section(String(localized: L10n.Common.operatorTitle)) {
        ForEach(AppSection.allCases) { item in
          Label { Text(item.title) } icon: { Image(systemName: item.symbol) }
            .badge(badge(for: item))
            .tag(item)
            .accessibilityIdentifier(item.rowID)
        }
      }
    }
    .listStyle(.sidebar)
    .safeAreaInset(edge: .bottom) { BotStateCard().padding(Tokens.Space.m) }
  }

  private func badge(for item: AppSection) -> Int {
    item == .trades ? model.shownTradeCount : 0
  }
}

/// Bot state at the foot of the sidebar: a pulsing dot while it runs.
private struct BotStateCard: View {
  @Environment(AppModel.self) private var model

  /// Characters of the run id shown; enough to tell runs apart.
  static let runIdPrefix = 8

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(L10n.Common.bot)
      HStack(spacing: Tokens.Space.s) {
        PulseDot(color, pulsing: model.status?.botState == .running && model.isLive)
        Text(verbatim: stateText).font(Tokens.Typography.callout.weight(.semibold)).foregroundStyle(color)
      }
      if let run = model.status?.runId {
        Text(L10n.Root.run(String(run.prefix(Self.runIdPrefix))))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
      }
      Text(verbatim: model.baseURL.host() ?? model.baseURL.absoluteString)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .apertureCard(radius: Tokens.Radius.large)
  }

  private var stateText: String {
    if model.fetchError != nil { return String(localized: L10n.Root.apiUnreachable) }
    guard let response = model.response else { return String(localized: L10n.Root.connecting) }
    guard let status = response.status else { return String(localized: L10n.Common.unavailable) }
    if response.stale { return String(localized: L10n.Root.stale(status.botState.title)) }
    return status.entryStop ? String(localized: L10n.Root.statePaused(status.botState.title)) : status.botState.title
  }

  private var color: Color {
    guard let response = model.response, let status = response.status, !response.stale,
      model.fetchError == nil else { return Palette.lossText }
    switch status.botState {
    case .running: return status.entryStop ? Palette.warningText : Palette.accentText
    case .starting, .stopping: return Palette.warningText
    case .stopped: return Palette.textQuaternary
    }
  }
}

/// Toolbar: ‹ day › with a menu of recorded days, and Today.
private struct DayToolbar: ToolbarContent {
  @Environment(AppModel.self) private var model

  /// SF Symbols of the previous and next day buttons.
  static let previousSymbol = "chevron.left"
  static let nextSymbol = "chevron.right"

  var body: some ToolbarContent {
    ToolbarItemGroup(placement: .navigation) {
      Button { model.showPreviousDay() } label: { Label(String(localized: L10n.Toolbar.previousDay), systemImage: Self.previousSymbol) }
        .disabled(model.previousDay == nil)
        .help(Text(L10n.Toolbar.previousDayHelp))
      Menu {
        Button(String(localized: L10n.Common.today)) { model.showToday() }
        if !model.days.isEmpty { Divider() }
        ForEach(model.days.filter { $0.day != model.today }) { day in
          Button {
            model.selectedDay = day.day
          } label: {
            Text(L10n.Toolbar.dayRow(Format.dayLabel(day.day), Money.signed(day.resultGrossUsd.value), day.trades))
          }
        }
      } label: {
        Group {
          if model.isLive {
            Text(L10n.Common.todayDay(Format.dayLabel(model.today)))
          } else {
            Text(verbatim: Format.dayLabel(model.shownDay))
          }
        }
        .font(Tokens.Typography.calloutMono)
      }
      .help(Text(L10n.Toolbar.pickDayHelp))
      Button { model.showNextDay() } label: { Label(String(localized: L10n.Toolbar.nextDay), systemImage: Self.nextSymbol) }
        .disabled(model.isLive)
        .help(Text(L10n.Toolbar.nextDayHelp))
    }
    ToolbarItem(placement: .status) {
      ConnectionStatus()
    }
    ToolbarItem(placement: .primaryAction) {
      if !model.isLive {
        Button(String(localized: L10n.Common.today)) { model.showToday() }.help(Text(L10n.Toolbar.todayHelp))
      }
    }
  }
}

/// The bot's address and how old its status is ("127.0.0.1 · 3 s ago"), with a dot in the
/// headline's colour; the tooltip says what the headline says.
private struct ConnectionStatus: View {
  @Environment(AppModel.self) private var model

  /// How often the age refreshes, in seconds.
  static let tick: TimeInterval = 1
  /// Accessibility id of the item, for the UI tests.
  static let id = "toolbar-connection"

  var body: some View {
    TimelineView(.periodic(from: .now, by: Self.tick)) { context in
      HStack(spacing: Tokens.Space.s) {
        // Pulses only while a fresh status keeps arriving; a down or silent bot's dot holds still.
        PulseDot(model.headline.severity.color, size: Tokens.Size.dotSmall, pulsing: isFresh)
        Text(verbatim: text(now: model.botTime(context.date)))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textTertiary)
      }
    }
    .help(Text(verbatim: model.headline.text))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(Self.id)
  }

  private var isFresh: Bool { model.response?.stale == false && model.fetchError == nil }

  private func text(now: Date) -> String {
    let host = model.baseURL.host() ?? model.baseURL.absoluteString
    guard let written = model.status?.writtenAt.date else { return host }
    return String(localized: L10n.Toolbar.connection(host, Format.age(since: written, now: now)))
  }
}

/// Open positions with no running bot behind them: shown above every screen for as long as the
/// status says so, since nothing closes these positions at the session's end.
struct UnattendedBanner: View {
  let unattended: Unattended

  /// SF Symbol of the banner.
  static let symbol = "exclamationmark.octagon.fill"

  var body: some View {
    HStack(alignment: .top, spacing: Tokens.Space.m) {
      Image(systemName: Self.symbol)
        .font(Tokens.Typography.symbol)
        .foregroundStyle(Palette.loss)
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(unattended.reason == .stopped ? L10n.Bot.stoppedTitle : L10n.Bot.silentTitle)
          .font(Tokens.Typography.callout.weight(.semibold))
        Text(unattended.reason == .stopped ? L10n.Bot.stoppedOpen(unattended.count) : L10n.Bot.silentOpen(unattended.count))
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(Tokens.Space.m)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium).strokeBorder(Palette.loss.opacity(Tokens.Opacity.border)))
    .accessibilityElement(children: .combine)
  }
}

/// The result of a command the operator sent, shown at the bottom of the window.
struct CommandToast: View {
  let command: SentCommand

  /// Floating shadow under the toast: blur and downward offset, in points.
  static let shadowRadius: CGFloat = 12
  static let shadowOffset: CGFloat = 6

  var body: some View {
    HStack(spacing: Tokens.Space.m) {
      Image(systemName: symbol).foregroundStyle(color)
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(verbatim: headline).font(Tokens.Typography.callout.weight(.semibold))
        if let detail {
          Text(verbatim: detail).font(Tokens.Typography.caption).foregroundStyle(Palette.textTertiary)
        }
      }
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .background(.regularMaterial, in: Capsule())
    .overlay(Capsule().strokeBorder(color.opacity(Tokens.Opacity.border)))
    .shadow(radius: Self.shadowRadius, y: Self.shadowOffset)
  }

  private var headline: String {
    switch command.outcome {
    case nil: return String(localized: L10n.Toast.queued(command.title))
    case .done: return String(localized: L10n.Toast.done(command.title))
    case .refused: return String(localized: L10n.Toast.refused(command.title))
    }
  }

  private var detail: String? {
    if let cause = command.cause { return cause }
    if let warning = command.warning { return String(localized: L10n.Toast.warning(warning)) }
    return command.outcome == nil ? String(localized: L10n.Toast.resultLater) : nil
  }

  /// SF Symbols of a queued, done and refused command.
  static let queuedSymbol = "clock.arrow.circlepath"
  static let doneSymbol = "checkmark.circle.fill"
  static let refusedSymbol = "xmark.octagon.fill"

  private var symbol: String {
    switch command.outcome {
    case nil: return Self.queuedSymbol
    case .done: return Self.doneSymbol
    case .refused: return Self.refusedSymbol
    }
  }

  private var color: Color {
    switch command.outcome {
    case nil: return Palette.infoText
    case .done: return Palette.profitText
    case .refused: return Palette.lossText
    }
  }
}

#if DEBUG
#Preview {
  RootView()
    .environment(PreviewAPI.model())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
