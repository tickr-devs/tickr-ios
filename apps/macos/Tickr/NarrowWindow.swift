import SwiftUI
import TickrDesign

/// What a main window narrower than its comfortable least size changes (owner decision
/// 2026-11-16, option A; the MainNarrow v110 board): what the title bar holds, and whether the
/// sidebar is an icon rail. Read from the window's width and the title bar's data only, never from
/// a layout pass, so a resize crosses each threshold once and nothing feeds back into the width.
struct WindowWidthFit: Equatable {
  /// What the title bar holds beside its line.
  var titleBar = TitleBarFit.whole
  /// The sidebar is an icon rail (`SidebarRail`): the window is too narrow for the full sidebar
  /// beside two columns of Overview cards.
  var rail = false

  /// A window at its comfortable width or wider: the title bar whole, the full sidebar.
  static let wide = WindowWidthFit()

  /// The fit for a window `width` points wide; nil (not measured yet) is `wide`.
  @MainActor
  static func make(width: CGFloat?, model: AppModel, chart: ChartModel) -> WindowWidthFit {
    guard let width else { return .wide }
    let rail = width < railBelowWidth
    let lead = rail ? TitleBarWidth.hiddenSidebarLead : RootView.sidebarMax
    return WindowWidthFit(titleBar: TitleBarFit.make(width: width, lead: lead, model: model, chart: chart), rail: rail)
  }

  /// Narrowest width taken for a real window's, in points: one Overview column beside the icon
  /// rail. A split view's first layout passes run narrower (1 and 237 points, read on the
  /// fixtures): `RootView` ignores those widths.
  @MainActor static let leastMeasured: CGFloat = RootView.railWidth + OverviewView.leastSize.width

  /// Narrowest window, in points, with the full sidebar: the sidebar at its preferred width
  /// beside Overview's two columns of cards. Narrower, the sidebar is an icon rail, so Overview
  /// keeps two columns as long as the rail allows and the board's one column below that.
  @MainActor static let railBelowWidth: CGFloat = RootView.sidebarIdeal + OverviewView.twoColumnsMinScreenWidth
}

/// What the title bar holds beside its line, the first of these that fits the window whole
/// (owner rule 2026-11-16: no text in the title bar is cut or moved into the "»" overflow menu).
struct TitleBarFit: Equatable {
  /// The day stepper ‹ day › and Today stay in the title bar; otherwise they sit in Overview's
  /// header beside the wordmark (MainNarrow v110).
  var stepper: Bool
  /// The connection status as "127.0.0.1 · age 2 s"; otherwise as its dot alone, the text in its
  /// tooltip and accessibility label (MainNarrow v110, 640-point board).
  var statusText: Bool
  /// The line names the bot's code version ("price-action-v1 v1 · code 6c4eec8b"); otherwise
  /// the strategy alone, as the design boards' line reads.
  var code: Bool

  static let whole = TitleBarFit(stepper: true, statusText: true, code: true)
  /// From the most to the least the title bar holds.
  static let tiers: [TitleBarFit] = [
    whole,
    TitleBarFit(stepper: false, statusText: true, code: true),
    TitleBarFit(stepper: false, statusText: true, code: false),
    TitleBarFit(stepper: false, statusText: false, code: false),
  ]

  /// The first tier whose items fit a window `width` wide whose toolbar starts `lead` points in;
  /// the last one when none does.
  @MainActor
  static func make(width: CGFloat, lead: CGFloat, model: AppModel, chart: ChartModel) -> TitleBarFit {
    if width >= TitleBarWidth.need(model: model, chart: chart) { return .whole }
    // A margin of one more gap: at exactly its need (1024 points, a long translated line with the
    // code version beside the full status) AppKit moved the status into the overflow menu.
    for tier in tiers.dropFirst()
    where width >= TitleBarWidth.need(tier, lead: lead, model: model, chart: chart) + TitleBarWidth.itemGap {
      return tier
    }
    return tiers.last ?? .whole
  }
}

extension EnvironmentValues {
  /// The main window's narrow-width fit (`WindowWidthFit`), set by `RootView`.
  @Entry var windowFit = WindowWidthFit.wide
}

/// Items in lines, each line from the leading edge and its items centred on one another, wrapping
/// at the offered width: a row of facts that goes onto a second line rather than cut a text.
struct WrapRow: Layout {
  var spacing: CGFloat = Tokens.Space.s
  var lineSpacing: CGFloat = Tokens.Space.xs

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let lines = lines(width: proposal.width ?? .infinity, subviews: subviews)
    let width = lines.map(\.width).max() ?? 0
    let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(lines.count - 1, 0))
    return CGSize(width: proposal.width ?? width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for line in lines(width: bounds.width, subviews: subviews) {
      var x = bounds.minX
      for index in line.indices {
        let size = Self.size(subviews[index], width: bounds.width)
        subviews[index].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += line.height + lineSpacing
    }
  }

  private struct Line {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  /// An item's own size, wrapped to the row's width when it is wider (a long text on its own line).
  private static func size(_ subview: LayoutSubview, width: CGFloat) -> CGSize {
    let ideal = subview.sizeThatFits(.unspecified)
    guard ideal.width > width else { return ideal }
    return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
  }

  private func lines(width: CGFloat, subviews: Subviews) -> [Line] {
    var lines: [Line] = []
    var line = Line()
    for index in subviews.indices {
      let size = Self.size(subviews[index], width: width)
      let needed = line.indices.isEmpty ? size.width : line.width + spacing + size.width
      if needed > width && !line.indices.isEmpty {
        lines.append(line)
        line = Line()
      }
      line.width = line.indices.isEmpty ? size.width : line.width + spacing + size.width
      line.height = max(line.height, size.height)
      line.indices.append(index)
    }
    if !line.indices.isEmpty { lines.append(line) }
    return lines
  }
}

/// The live flow's stages in rows of equal cells: one row while every cell is at least
/// `leastCellWidth` wide (the stage's ring and its longest word), else as few rows as that allows
/// with the stages shared evenly (9 stages: 5 and 4), each row centred. So a stage name breaks
/// only between its words (MainNarrow v110: `.stage{min-width:min-content}`, `word-break:keep-all`).
/// The first subview is the track behind the first row's rings, from the first ring's centre to
/// the last one's; the others are the stages.
struct StageRows: Layout {
  let leastCellWidth: CGFloat
  /// Height of the track's line and how far down from a row's top it runs (the ring's centre).
  let trackHeight: CGFloat
  let trackY: CGFloat
  var rowSpacing: CGFloat = Tokens.Space.m

  /// Least width of a stage's cell, in points: its ring, or the longest word of any stage's name
  /// as it is drawn (upper case, `annotationBold`, `labelTracking`) or of its value
  /// (`annotation`: "141 cotizados"), with the column's padding.
  static func leastCellWidth(names: [String], values: [String]) -> CGFloat {
    // `annotation` and `annotationBold`: caption 2 on iOS, `annotationSize` on the Mac.
    let size = TextMeasure.pointSize(mac: Tokens.Typography.annotationSize, ios: .caption2)
    let bold = PlatformFont.monospacedSystemFont(ofSize: size, weight: .bold)
    let regular = PlatformFont.monospacedSystemFont(ofSize: size, weight: .regular)
    let nameWords = names.flatMap { $0.uppercased().split(whereSeparator: \.isWhitespace) }
      .map { TextMeasure.width(String($0), font: bold, kern: Tokens.Typography.labelTracking) }
    let valueWords = values.flatMap { $0.split(whereSeparator: \.isWhitespace) }
      .map { TextMeasure.width(String($0), font: regular) }
    let longest = (nameWords + valueWords).max() ?? 0
    return max(Tokens.Size.stage, longest) + Tokens.Space.xs * CardArrangement.paddedEdges
  }

  /// Stages in each row for `count` stages in `width`: all in one row when they fit, else the
  /// fewest rows they fit in, shared evenly, the first rows the fuller.
  static func perRow(count: Int, width: CGFloat, leastCellWidth: CGFloat) -> Int {
    guard count > 0 else { return 0 }
    let fit = max(Int(width / max(leastCellWidth, 1)), 1)
    guard fit < count else { return count }
    let rows = (count + fit - 1) / fit
    return (count + rows - 1) / rows
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let stages = subviews.dropFirst()
    let width = proposal.width ?? leastCellWidth * CGFloat(stages.count)
    let rows = cells(width: width, count: stages.count)
    let height = rows.map { row in
      row.map { stages[stages.startIndex + $0.index].sizeThatFits(ProposedViewSize(width: $0.frame.width, height: nil)).height }
        .max() ?? 0
    }
    return CGSize(width: width, height: height.reduce(0, +) + rowSpacing * CGFloat(max(height.count - 1, 0)))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard let track = subviews.first else { return }
    let stages = subviews.dropFirst()
    let rows = cells(width: bounds.width, count: stages.count)
    var y = bounds.minY
    for (number, row) in rows.enumerated() {
      var height: CGFloat = 0
      for cell in row {
        let proposal = ProposedViewSize(width: cell.frame.width, height: nil)
        let stage = stages[stages.startIndex + cell.index]
        height = max(height, stage.sizeThatFits(proposal).height)
        stage.place(at: CGPoint(x: bounds.minX + cell.frame.minX, y: y), proposal: proposal)
      }
      if number == 0, let first = row.first, let last = row.last {
        let width = last.frame.midX - first.frame.midX
        track.place(at: CGPoint(x: bounds.minX + first.frame.midX, y: y + trackY - trackHeight / 2),
          proposal: ProposedViewSize(width: width, height: trackHeight))
      }
      y += height + rowSpacing
    }
  }

  /// Each row's cells: the stage's index and its frame's horizontal extent (y unused).
  private func cells(width: CGFloat, count: Int) -> [[(index: Int, frame: CGRect)]] {
    let perRow = Self.perRow(count: count, width: width, leastCellWidth: leastCellWidth)
    guard perRow > 0 else { return [] }
    // Every row's cells as wide as the first row's, so the rings line up in columns.
    let cell = width / CGFloat(perRow)
    return stride(from: 0, to: count, by: perRow).map { start in
      let indices = Array(start..<min(start + perRow, count))
      let offset = (width - cell * CGFloat(indices.count)) / 2
      return indices.enumerated().map { position, index in
        (index, CGRect(x: offset + cell * CGFloat(position), y: 0, width: cell, height: 0))
      }
    }
  }
}
