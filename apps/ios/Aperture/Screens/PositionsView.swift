import ApertureDesign
import ApertureKit
import SwiftUI

/// Open positions: one picker chip per position, then the selected one with its protection chain,
/// risk numbers and a Flatten button.
struct PositionsView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Screen(L10n.App.positions) {
      ConnectionPrompt()
      if let status = model.status {
        let positions = Board.positions(status)
        if positions.isEmpty {
          ContentUnavailableView {
            Label { Text(L10n.Positions.none) } icon: { Image(systemName: "lock.open") }
          } description: {
            if let block = status.entryBlock {
              Text(verbatim: block.text)
            } else {
              Text(L10n.Positions.watching)
            }
          }
          .rise()
        } else {
          PositionChips(positions: positions)
            .rise(step: PositionDetail.Order.chips.rawValue)
          if let position = positions.first(where: { $0.symbol == model.selectedSymbol }) ?? positions.first {
            PositionDetail(position: position)
              .id(position.symbol)
              .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
          }
        }
      }
    }
    .animation(Tokens.Motion.standard, value: model.selectedSymbol)
    .refreshable { await model.refresh() }
  }
}

private struct PositionChips: View {
  @Environment(AppModel.self) private var model
  let positions: [Position]

  var body: some View {
    let selected = model.selectedSymbol ?? positions.first?.symbol
    HStack(spacing: Tokens.Space.s) {
      ForEach(positions, id: \.symbol) { position in
        let isSelected = position.symbol == selected
        Button {
          model.selectedSymbol = position.symbol
        } label: {
          VStack(spacing: Tokens.Space.xxs) {
            Text(verbatim: position.symbol).font(.footnote.monospaced().bold())
            Group {
              if position.stop.state.isProtected {
                Text(L10n.Positions.protected)
              } else {
                Text(verbatim: Board.stopStateTitle(position.stop.state))
              }
            }
            .font(Tokens.Typography.annotationBold)
            .foregroundStyle(position.stop.state.isProtected ? Palette.profitText : Palette.lossText)
          }
          .frame(maxWidth: .infinity, minHeight: Tokens.Size.iconWell)
          .foregroundStyle(Palette.textPrimary)
          .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
              .fill(isSelected ? Palette.info.opacity(Tokens.Opacity.wash) : Palette.surface))
          .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
              .strokeBorder(isSelected ? Palette.info : Palette.separatorStrong))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }
  }
}

private struct PositionDetail: View {
  /// Order in which the blocks rise in (`rise(step:)`).
  enum Order: Int { case chips = 1, title, levels, chain, stats, flatten }

  /// Height of the Flatten button, in points.
  static let buttonHeight: CGFloat = 50
  /// Multiplies a fraction into percent.
  static let percent: Decimal = 100
  /// Digits after the point of the distance to the stop, in percent.
  static let percentDigits = 1

  @Environment(AppModel.self) private var model
  @State private var confirmFlatten = false
  let position: Position

  var body: some View {
    let entry = position.entryPrice.value
    let stop = position.stop.price?.value
    let quantity = position.quantity.value
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        Text(verbatim: position.symbol)
          .font(.largeTitle.monospaced().bold())
        Text(L10n.Positions.shares(position.quantity.text, position.entryPrice.text,
          Format.clock(position.openedAt.date)))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textTertiary)
      }
      .rise(step: Order.title.rawValue)

      LevelsCard(entry: entry, stop: stop).rise(step: Order.levels.rawValue)
      ProtectionChain(position: position).rise(step: Order.chain.rawValue)

      HStack(spacing: Tokens.Space.s) {
        StatTile(label: L10n.Positions.maxLoss,
          value: Risk.plannedLoss(entry: entry, stop: stop, quantity: quantity).map { Money.plain($0) }
            ?? Format.missing)
        StatTile(label: L10n.Positions.stop,
          value: position.stop.price?.text ?? Format.missing,
          color: position.stop.state.isProtected ? Palette.profitText : Palette.lossText)
        StatTile(label: L10n.Positions.toStop,
          value: stop.map {
            Money.plain((entry - $0) / entry * Self.percent, fractionDigits: Self.percentDigits) + Format.percentSign
          } ?? Format.missing)
      }
      .rise(step: Order.stats.rawValue)

      Button(role: .destructive) {
        confirmFlatten = true
      } label: {
        Text(L10n.Positions.flattenEllipsis(position.symbol))
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity, minHeight: Self.buttonHeight)
          .foregroundStyle(Palette.lossText)
          .background(Palette.loss.opacity(Tokens.Opacity.wash),
            in: RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
            .strokeBorder(Palette.loss.opacity(Tokens.Opacity.border)))
      }
      .buttonStyle(.plain)
      .disabled(!model.canCommand)
      .opacity(model.canCommand ? 1 : Tokens.Opacity.border)
      .rise(step: Order.flatten.rawValue)
      .confirmationDialog(Text(L10n.Positions.closeNow(position.symbol)), isPresented: $confirmFlatten,
        titleVisibility: .visible) {
        if model.canCommand {
          Button(role: .destructive) {
            Task { await BotControl.confirmAndSend(.flatten, model: model) }
          } label: {
            Text(L10n.Positions.flatten(position.symbol))
          }
        }
        Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
      } message: {
        Text(L10n.Positions.flattenMessage)
      }
    }
  }
}

/// Entry and stop as two levels with the distance between them shaded; the live price line comes
/// with bar data from the API.
private struct LevelsCard: View {
  /// Height of the band drawing, in points.
  static let height: CGFloat = 110
  /// Where the entry line sits, as a fraction of the drawing's height from the top.
  static let entryLevel: CGFloat = 0.2
  /// Where the stop line sits, as a fraction of the drawing's height from the top.
  static let stopLevel: CGFloat = 0.82
  /// How far a level's label sits above its line, in points.
  static let labelLift: CGFloat = 9

  @State private var drawn = false
  let entry: Decimal
  let stop: Decimal?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack {
        CardLabel(L10n.Positions.riskBand)
        Spacer()
        Text(L10n.Positions.priceLineLater)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.highlightText)
      }
      GeometryReader { geometry in
        let height = geometry.size.height
        let width = geometry.size.width
        ZStack(alignment: .topLeading) {
          Rectangle()
            .fill(LinearGradient(colors: [Palette.accent.opacity(Tokens.Opacity.glow),
              Palette.loss.opacity(Tokens.Opacity.wash)], startPoint: .top, endPoint: .bottom))
            .frame(height: height * (Self.stopLevel - Self.entryLevel))
            .offset(y: height * Self.entryLevel)
            .scaleEffect(x: 1, y: drawn ? 1 : 0, anchor: .top)
          level(L10n.Positions.entryLevel(Money.plain(entry)), color: Palette.textQuaternary,
            textColor: Palette.textTertiary, y: height * Self.entryLevel, width: width)
          if let stop {
            level(L10n.Positions.stopLevel(Money.plain(stop)), color: Palette.loss, textColor: Palette.lossText,
              y: height * Self.stopLevel, width: width)
          }
        }
      }
      .frame(height: Self.height)
    }
    .padding(Tokens.Space.m)
    .apertureCard()
    .onAppear {
      withAnimation(Tokens.Motion.draw.delay(Tokens.Motion.stagger * Double(PositionDetail.Order.flatten.rawValue))) {
        drawn = true
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(L10n.Positions.levels(Money.plain(entry),
      stop.map { Money.plain($0) } ?? String(localized: L10n.Common.unknown))))
  }

  private func level(_ text: LocalizedStringResource, color: Color, textColor: Color, y: CGFloat, width: CGFloat)
    -> some View {
    ZStack(alignment: .leading) {
      Path { path in
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: width, y: 0))
      }
      .stroke(color, style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash))
      .frame(height: Tokens.Stroke.thin)
      .clipped()
      Text(text)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(textColor)
        .padding(.horizontal, Tokens.Space.xs)
        .background(Palette.surface)
        .offset(x: Tokens.Space.xs, y: -Self.labelLift)
    }
    .offset(y: y)
  }
}

/// What the bot proved about this position, step by step, drawn top to bottom.
private struct ProtectionChain: View {
  /// Side of a step's dot, in points.
  static let dotSide: CGFloat = 14
  /// Glow around a step's dot, in points.
  static let glowRadius: CGFloat = 5
  /// Scale of a dot the drawn line has not reached yet (not zero, so the transform stays invertible).
  static let hiddenScale: CGFloat = 0.01

  @State private var progress: CGFloat = 0
  let position: Position

  var body: some View {
    let steps = self.steps
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      CardLabel(L10n.Positions.chain)
      ZStack(alignment: .topLeading) {
        GeometryReader { geometry in
          Capsule().fill(Palette.separator).frame(width: Tokens.Stroke.bold)
          Capsule().fill(Palette.profit).frame(width: Tokens.Stroke.bold, height: geometry.size.height * progress)
        }
        .frame(width: Tokens.Stroke.bold)
        .padding(.leading, (Self.dotSide - Tokens.Stroke.bold) / 2)
        .padding(.vertical, Self.dotSide / 2)
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
          ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
            HStack(spacing: Tokens.Space.m) {
              Circle()
                .fill(step.ok ? Palette.profit : Palette.loss)
                .frame(width: Self.dotSide, height: Self.dotSide)
                .shadow(color: (step.ok ? Palette.profit : Palette.loss).opacity(Tokens.Opacity.medium),
                  radius: Self.glowRadius)
                .scaleEffect(progress >= CGFloat(index) / CGFloat(max(steps.count - 1, 1)) ? 1 : Self.hiddenScale)
              Text(step.label).font(.footnote)
              Spacer()
              Text(verbatim: step.detail)
                .font(Tokens.Typography.annotation)
                .foregroundStyle(Palette.textQuaternary)
            }
          }
        }
      }
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .apertureCard()
    .onAppear {
      withAnimation(Tokens.Motion.fill.delay(Tokens.Motion.stagger * Double(PositionDetail.Order.flatten.rawValue))) {
        progress = 1
      }
    }
  }

  private var steps: [(label: LocalizedStringResource, detail: String, ok: Bool)] {
    let state = position.stop.state
    return [
      (L10n.Positions.filled(position.quantity.text, position.entryPrice.text), Format.clock(position.openedAt.date),
        true),
      (L10n.Positions.stopSent(position.stop.price?.text ?? ""), position.stop.clientOrderId ?? Format.missing,
        state == .pending || state == .verified),
      (L10n.Positions.stopWorking, Board.stopStateTitle(state), state.isProtected),
    ]
  }
}
