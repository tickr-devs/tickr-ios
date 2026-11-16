import Charts
import SwiftUI
import TickrDesign
import TickrKit

/// "Today if each version traded": the running result of the trading strategy (real trades) and
/// of every observer (simulated trades) through the day, one line each, with the totals below.
/// The lines draw themselves in from the left on appear and again when a version closes a trade
/// (the board's `draw`); still with Reduce Motion.
struct VersionsCard: View {
  /// Height of the chart, in points.
  static let chartHeight: CGFloat = 120
  /// Width and height of a legend swatch, in points.
  static let swatchWidth: CGFloat = 10
  static let swatchHeight: CGFloat = 3
  /// Observers' colours, in their order; the trading strategy is always the accent.
  static let observerColors: [Color] = [Palette.highlight, Palette.warning, Palette.info, Palette.seriesATR]

  let curves: [VersionCurve]
  /// Why some observers have no line (their trades could not be listed), one per observer.
  let missing: [String]
  /// Where every line ends: now on a live day, the last close on a past one.
  let end: Date

  private func color(_ curve: VersionCurve) -> Color {
    guard curve.observer, let index = curves.filter(\.observer).firstIndex(of: curve) else { return Palette.accent }
    return Self.observerColors[index % Self.observerColors.count]
  }

  /// When every line starts at zero: just before the first close of any version.
  private var start: Date? { curves.compactMap { $0.points.first?.at }.min() }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      // The label, then its note; the note goes under it at large text sizes.
      RowStack {
        CardLabel(L10n.Lab.versions)
        Spacer()
        Text(L10n.Lab.noOrders)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      if let start {
        Chart {
          RuleMark(y: .value(String(localized: L10n.Lab.result), 0))
            .foregroundStyle(Palette.separatorStrong)
            .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
          ForEach(curves) { curve in
            let points = [VersionCurve.Point(at: start, total: 0)] + curve.points
              + [VersionCurve.Point(at: max(end, curve.points.last?.at ?? start), total: curve.points.last?.total ?? 0)]
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
              LineMark(x: .value(String(localized: L10n.Lab.time), point.at),
                y: .value(String(localized: L10n.Lab.result), NSDecimalNumber(decimal: point.total).doubleValue),
                series: .value(String(localized: L10n.Lab.version), curve.id))
                .interpolationMethod(.stepEnd)
                .foregroundStyle(color(curve))
                .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.bold, dash: curve.complete ? [] : Tokens.Stroke.dash))
            }
            // A glowing dot where the line ends, as on the design.
            if let last = points.last {
              PointMark(x: .value(String(localized: L10n.Lab.time), last.at),
                y: .value(String(localized: L10n.Lab.result), NSDecimalNumber(decimal: last.total).doubleValue))
                .symbol {
                  Circle()
                    .fill(color(curve))
                    .frame(width: Tokens.Size.dot, height: Tokens.Size.dot)
                    .shadow(color: color(curve), radius: Tokens.Size.glowRadius / 2)
                }
            }
          }
        }
        // As on the design: the lines alone, no axes or grid.
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: Self.chartHeight)
        .drawsIn(on: curves.map(\.points))
        .accessibilityHidden(true)
      } else {
        Text(L10n.Lab.noClosed)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textTertiary)
      }
      ForEach(curves) { curve in
        // The name, its role as a pill and the total in one row; at large text sizes each takes
        // its own line, so the name wraps whole instead of breaking letter by letter.
        RowStack(spacing: Tokens.Space.s) {
          HStack(spacing: Tokens.Space.s) {
            Capsule().fill(color(curve)).frame(width: Self.swatchWidth, height: Self.swatchHeight)
            Text(L10n.Common.strategyVersion(curve.name, curve.version))
              .font(Tokens.Typography.calloutMono)
              .foregroundStyle(Palette.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .layoutPriority(1)
          StatusPill(curve.observer ? L10n.Lab.observerRole : L10n.Lab.trades,
            systemImage: curve.observer ? LabView.observerSymbol : LabView.tradesSymbol,
            tone: curve.observer ? .highlight : .accent)
          Spacer(minLength: 0)
          if let total = curve.total {
            Text(verbatim: Money.signed(total))
              .font(Tokens.Typography.calloutMono.bold())
              .foregroundStyle(Palette.result(total))
              .fixedSize()
          } else {
            Text(L10n.Lab.partial)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
        .accessibilityElement(children: .combine)
      }
      ForEach(missing, id: \.self) { cause in
        Text(verbatim: cause)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
  }
}
