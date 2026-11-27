import SwiftUI
import TickrKit

// The live flow's stages drawn small, as on the IOS2Home and IOS2Funnel boards (mockup v155): the
// one-line funnel of rings (`FunnelRings`) and the funnel sheet's bars (`FunnelBarRow`). Each stage
// keeps its one colour (`PipelineStage.fill`), glyph and name (`PipelineStage.title`), the Mac's.

public extension PipelineStage {
  /// The stage's line glyph, as on the Mac's live flow.
  var glyph: DesignGlyph {
    switch self {
    case .screeners: .screeners
    case .universe: .universe
    case .quote: .quote
    case .bars: .bars
    case .strategy: .strategy
    case .risk: .risk
    case .order: .order
    case .stop: .brokerStop
    case .reconcile: .reconcile
    }
  }
}

/// One stage of a funnel drawing: its colour, what it shows and how many symbols it dropped.
public struct FunnelStage: Identifiable, Hashable, Sendable {
  public let stage: PipelineStage
  /// Fill of its ring and bar: `stage.fill` while healthy, the state's tone otherwise
  /// (`Palette.textQuaternary` while not reported).
  public let color: Color
  /// Its name's colour: `stage.text`, or the state's tone's text.
  public let text: Color
  /// The figure its bar is drawn to; nil draws no bar.
  public let count: Int?
  /// What it shows ("412", "OK"); nil while the bot does not report it (a dash, the ring faint).
  public let value: String?
  /// Symbols it dropped today ("−144", pink); nil when none.
  public let dropped: Int?

  public var id: PipelineStage { stage }

  public init(stage: PipelineStage, color: Color, text: Color, count: Int?, value: String?, dropped: Int? = nil) {
    self.stage = stage
    self.color = color
    self.text = text
    self.count = count
    self.value = value
    self.dropped = dropped
  }
}

/// The funnel on one line (iOS Home): each stage's ring, its glyph in its colour on a tint of it,
/// spread along a faint rail in the stages' colours. A stage not reported is faint; a ring pulses
/// once when its value changes while `moving`. While `moving`, lights run along the rail (an
/// ornament that reads as "the bot is at work", gated by the caller as Home's other ornaments).
public struct FunnelRings: View {
  let stages: [FunnelStage]
  let moving: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(_ stages: [FunnelStage], moving: Bool) {
    self.stages = stages
    self.moving = moving
  }

  public var body: some View {
    ZStack {
      rail
      HStack(spacing: 0) {
        ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
          if index > 0 { Spacer(minLength: Tokens.Space.xxs) }
          ring(stage)
        }
      }
    }
    .frame(height: Tokens.Size.funnelLine)
    .accessibilityHidden(true)
  }

  /// The rail from the first ring's centre to the last one's, and the lights running along it.
  private var rail: some View {
    let inset = Tokens.Size.funnelRing / 2
    return ZStack {
      Capsule()
        .fill(LinearGradient(colors: PipelineStage.allCases.map(\.fill), startPoint: .leading, endPoint: .trailing))
        .frame(height: Tokens.Stroke.bold)
        .opacity(Tokens.Opacity.funnelRail)
      if moving && !reduceMotion {
        travellers
      }
    }
    .padding(.horizontal, inset)
  }

  /// Lights a run apart along the rail, fading in at its start and out at its end.
  private var travellers: some View {
    // decorative: the lights along the rail say the bot is at work; they carry no data.
    TimelineView(.animation(paused: !moving)) { context in
      GeometryReader { proxy in
        let run = Tokens.Motion.funnelTravelSeconds
        let count = Tokens.Motion.funnelTravellers
        let now = context.date.timeIntervalSinceReferenceDate
        ForEach(0..<count, id: \.self) { index in
          let share = ((now + run * Double(index) / Double(count)).truncatingRemainder(dividingBy: run)) / run
          Circle()
            .fill(PipelineStage.screeners.fill)
            .frame(width: Tokens.Size.funnelTraveller, height: Tokens.Size.funnelTraveller)
            .shadow(color: PipelineStage.screeners.fill, radius: Tokens.Size.funnelTraveller / 2)
            .opacity(Self.fade(share))
            .position(x: proxy.size.width * share, y: proxy.size.height / 2)
        }
      }
    }
  }

  /// A light's opacity at `share` of its run: in over the first `funnelTravelFade`, out over the last.
  static func fade(_ share: Double) -> Double {
    let edge = Tokens.Motion.funnelTravelFade
    return min(1, share / edge, (1 - share) / edge)
  }

  private func ring(_ stage: FunnelStage) -> some View {
    let lit = stage.value != nil
    return ZStack {
      Circle().fill(Palette.surface)
      Circle().fill(stage.color.opacity(Tokens.Opacity.glow))
      Circle().strokeBorder(stage.color, lineWidth: Tokens.Stroke.regular)
      DesignGlyphView(stage.stage.glyph, side: Tokens.Size.funnelGlyph)
        .foregroundStyle(stage.color)
    }
    .frame(width: Tokens.Size.funnelRing, height: Tokens.Size.funnelRing)
    .shadow(color: lit ? stage.color.opacity(Tokens.Opacity.faint) : .clear, radius: Tokens.Size.funnelRing / 2)
    .opacity(lit ? 1 : Tokens.Opacity.faint)
    .eventPulse(Circle(), color: stage.color, scale: Tokens.Motion.pulseScale, event: lit && moving ? stage.value : nil)
  }
}

/// A stage of the funnel sheet (IOS2Funnel): its name in its colour, its bar centred in the row and
/// as wide as its count against the widest stage's, then its value and what it dropped ("−144").
/// The names and the values of every row of `stages` line up in columns as wide as the widest of
/// each; at large text sizes the name takes a line over the bar. VoiceOver reads the row as one.
public struct FunnelBarRow: View {
  let stage: FunnelStage
  let stages: [FunnelStage]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var grown = false

  /// Before a dropped count ("−144"), and between the value and it for VoiceOver.
  static let minus = "\u{2212}"
  static let separator = ", "

  public init(_ stage: FunnelStage, in stages: [FunnelStage]) {
    self.stage = stage
    self.stages = stages
  }

  public var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: Tokens.Space.s) {
        column { name($0) }
        track
        column { value($0) }
      }
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        name(stage)
        HStack(spacing: Tokens.Space.s) {
          track
          value(stage)
        }
      }
    }
    .frame(minHeight: Tokens.Size.funnelBar + Tokens.Space.s)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(stage.stage.title))
    .accessibilityValue(Text(verbatim: accessibilityValue))
    .onAppear {
      withAnimation(reduceMotion ? nil : Tokens.Motion.standard) { grown = true }
    }
  }

  /// This row's piece over every row's, hidden, so the column is as wide as its widest piece.
  private func column<Piece: View>(@ViewBuilder _ piece: @escaping (FunnelStage) -> Piece) -> some View {
    ZStack(alignment: .leading) {
      ForEach(stages) { other in piece(other).hidden() }
      piece(stage)
    }
  }

  private func name(_ stage: FunnelStage) -> some View {
    Text(stage.stage.title)
      .textCase(.uppercase)
      .font(Tokens.Typography.annotationBold)
      .tracking(Tokens.Typography.labelTracking)
      .foregroundStyle(stage.value == nil ? Palette.textQuaternary : stage.text)
      .fixedSize()
  }

  private func value(_ stage: FunnelStage) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
      Text(verbatim: stage.value ?? Money.missing)
        .font(Tokens.Typography.figure)
        .foregroundStyle(stage.value == nil ? Palette.textQuaternary : Palette.textPrimary)
        .contentTransition(.numericText())
      if let dropped = stage.dropped {
        Text(verbatim: Self.minus + dropped.formatted())
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.droppedText)
      }
    }
    .fixedSize()
  }

  /// The bar, centred in the room between the columns.
  private var track: some View {
    GeometryReader { proxy in
      if let share = share {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
        shape
          .fill(stage.color.opacity(Tokens.Opacity.muted))
          .overlay(shape.strokeBorder(stage.color, lineWidth: Tokens.Stroke.regular))
          .shadow(color: stage.color.opacity(Tokens.Opacity.faint), radius: Tokens.Space.s)
          .frame(width: max(Tokens.Size.funnelBarMin, proxy.size.width * share), height: Tokens.Size.funnelBar)
          .scaleEffect(x: grown ? 1 : 0)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(minWidth: Tokens.Size.funnelBarMin, maxWidth: .infinity, minHeight: Tokens.Size.funnelBar)
  }

  /// The bar's width as a share of the track: its count against the widest stage's; nil for no bar.
  private var share: CGFloat? {
    guard let count = stage.count, let widest = stages.compactMap(\.count).max(), widest > 0 else { return nil }
    return max(Tokens.Funnel.leastShare, CGFloat(count) / CGFloat(widest))
  }

  private var accessibilityValue: String {
    let shown = stage.value ?? Money.missing
    guard let dropped = stage.dropped else { return shown }
    return shown + Self.separator + Self.minus + dropped.formatted()
  }
}
