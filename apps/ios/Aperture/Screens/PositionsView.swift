import ApertureDesign
import ApertureKit
import SwiftUI

/// Open positions: one picker chip per position, then the selected one with its protection chain,
/// risk numbers and a Flatten button.
struct PositionsView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Screen("Positions") {
      ConnectionPrompt()
      if let status = model.status {
        let positions = Board.positions(status)
        if positions.isEmpty {
          ContentUnavailableView(
            "No open position",
            systemImage: "lock.open",
            description: Text(status.entryBlock?.text ?? "Entries are allowed; the bot is watching for signals."))
            .rise()
        } else {
          PositionChips(positions: positions)
            .rise(0.05)
          if let position = positions.first(where: { $0.symbol == model.selectedSymbol }) ?? positions.first {
            PositionDetail(position: position)
              .id(position.symbol)
              .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
          }
        }
      }
    }
    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: model.selectedSymbol)
    .refreshable { await model.refresh() }
  }
}

private struct PositionChips: View {
  @Environment(AppModel.self) private var model
  let positions: [Position]

  var body: some View {
    let selected = model.selectedSymbol ?? positions.first?.symbol
    HStack(spacing: 8) {
      ForEach(positions, id: \.symbol) { position in
        Button {
          model.selectedSymbol = position.symbol
        } label: {
          VStack(spacing: 3) {
            Text(position.symbol).font(.system(size: 13, weight: .bold, design: .monospaced))
            Text(position.stop.state.isProtected ? "protected" : position.stop.state.rawValue)
              .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
              .foregroundStyle(position.stop.state.isProtected ? Palette.greenStrong : Palette.redStrong)
          }
          .frame(maxWidth: .infinity, minHeight: 44)
          .foregroundStyle(Palette.text)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(position.symbol == selected ? Palette.blue.opacity(0.12) : Palette.card))
          .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .strokeBorder(position.symbol == selected ? Palette.blue : Palette.line2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(position.symbol == selected ? .isSelected : [])
      }
    }
  }
}

private struct PositionDetail: View {
  @Environment(AppModel.self) private var model
  @State private var confirmFlatten = false
  let position: Position

  var body: some View {
    let entry = position.entryPrice.value
    let stop = position.stop.price?.value
    let quantity = position.quantity.value
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(position.symbol)
          .font(.system(size: 30, weight: .bold, design: .monospaced))
        Text("\(position.quantity.text) shares @ \(position.entryPrice.text) · \(Format.clock(position.openedAt.date))")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(Palette.muted)
      }
      .rise(0.1)

      LevelsCard(entry: entry, stop: stop).rise(0.15)
      ProtectionChain(position: position).rise(0.2)

      HStack(spacing: 8) {
        StatTile(label: "max loss",
          value: Risk.plannedLoss(entry: entry, stop: stop, quantity: quantity).map { Money.plain($0) } ?? "—")
        StatTile(label: "stop",
          value: position.stop.price?.text ?? "—",
            color: position.stop.state.isProtected ? Palette.greenStrong : Palette.redStrong)
        StatTile(label: "to stop",
          value: stop.map { Money.plain((entry - $0) / entry * 100, fractionDigits: 1) + "%" } ?? "—")
      }
      .rise(0.25)

      Button(role: .destructive) {
        confirmFlatten = true
      } label: {
        Text("Flatten \(position.symbol)…")
          .font(.system(size: 15, weight: .semibold))
          .frame(maxWidth: .infinity, minHeight: 50)
          .foregroundStyle(Palette.redStrong)
          .background(Palette.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.red.opacity(0.5)))
      }
      .buttonStyle(.plain)
      .disabled(!model.canCommand)
      .opacity(model.canCommand ? 1 : 0.5)
      .rise(0.3)
      .confirmationDialog("Close \(position.symbol) now?", isPresented: $confirmFlatten, titleVisibility: .visible) {
        if model.canCommand {
          Button("Flatten \(position.symbol)", role: .destructive) {
            Task { await BotControl.confirmAndSend(.flatten, model: model) }
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("The bot cancels the stop, re-reads the quantity and sells at market through the normal exit. "
          + "Flatten closes every position the bot holds; positions not opened by the bot are not touched.")
      }
    }
  }
}

/// Entry and stop as two levels with the distance between them shaded; the live price line comes
/// with bar data from the API.
private struct LevelsCard: View {
  @State private var drawn = false
  let entry: Decimal
  let stop: Decimal?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        CardLabel("Risk band")
        Spacer()
        Text("price line comes with chart data")
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(Palette.violetStrong)
      }
      GeometryReader { geometry in
        let height = geometry.size.height
        ZStack(alignment: .topLeading) {
          Rectangle()
            .fill(LinearGradient(colors: [Palette.teal.opacity(0.18), Palette.red.opacity(0.12)],
              startPoint: .top, endPoint: .bottom))
            .frame(height: height * 0.62)
            .offset(y: height * 0.2)
            .scaleEffect(x: 1, y: drawn ? 1 : 0, anchor: .top)
          level("entry \(Money.plain(entry))", color: Palette.dim, textColor: Palette.muted, y: height * 0.2)
          if let stop {
            level("broker stop \(Money.plain(stop))", color: Palette.red, textColor: Palette.redStrong, y: height * 0.82)
          }
        }
      }
      .frame(height: 110)
    }
    .padding(12)
    .apertureCard()
    .onAppear { withAnimation(.easeOut(duration: 1.2).delay(0.3)) { drawn = true } }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Entry \(Money.plain(entry)), stop \(stop.map { Money.plain($0) } ?? "unknown")")
  }

  private func level(_ text: String, color: Color, textColor: Color, y: CGFloat) -> some View {
    ZStack(alignment: .leading) {
      Path { path in
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 2000, y: 0))
      }
      .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
      .frame(height: 1)
      .clipped()
      Text(text)
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(textColor)
        .padding(.horizontal, 4)
        .background(Palette.card)
        .offset(x: 4, y: -9)
    }
    .offset(y: y)
  }
}

/// What the bot proved about this position, step by step, drawn top to bottom.
private struct ProtectionChain: View {
  @State private var progress: CGFloat = 0
  let position: Position

  var body: some View {
    let steps = self.steps
    VStack(alignment: .leading, spacing: 10) {
      CardLabel("Protection chain")
      ZStack(alignment: .topLeading) {
        GeometryReader { geometry in
          Capsule().fill(Palette.line).frame(width: 2)
          Capsule().fill(Palette.green).frame(width: 2, height: geometry.size.height * progress)
        }
        .frame(width: 2)
        .padding(.leading, 7)
        .padding(.vertical, 6)
        VStack(alignment: .leading, spacing: 11) {
          ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
            HStack(spacing: 12) {
              Circle()
                .fill(step.ok ? Palette.green : Palette.red)
                .frame(width: 14, height: 14)
                .shadow(color: (step.ok ? Palette.green : Palette.red).opacity(0.6), radius: 5)
                .scaleEffect(progress >= CGFloat(index) / CGFloat(max(steps.count - 1, 1)) ? 1 : 0.01)
              Text(step.label).font(.system(size: 13))
              Spacer()
              Text(step.detail)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Palette.dim)
            }
          }
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .apertureCard()
    .onAppear { withAnimation(.spring(response: 1.6, dampingFraction: 0.9).delay(0.3)) { progress = 1 } }
  }

  private var steps: [(label: String, detail: String, ok: Bool)] {
    let state = position.stop.state
    return [
      ("Filled \(position.quantity) @ \(position.entryPrice)", Format.clock(position.openedAt.date), true),
      ("Stop \(position.stop.price?.text ?? "") sent once", position.stop.clientOrderId ?? "—",
      state == .pending || state == .verified),
      ("Stop working at broker", state.rawValue, state.isProtected),
    ]
  }
}
