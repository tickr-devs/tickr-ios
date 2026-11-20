import SwiftUI

/// A trade's or a decision's label on a chart's price pane, both apps: bold mono on a plate
/// washed in its colour, over the surface so it stays readable on the candles. Shown while few
/// marks are on screen (`Tokens.Chart.markLabelLimit`), and on the iPhone over the marks of the
/// candle a finger holds or taps (owner, 2026-11-20: "what are these dots, I can't tap them").
public struct ChartMarkPlate: View {
  let text: LocalizedStringResource
  let color: Color
  let textColor: Color

  public init(_ text: LocalizedStringResource, color: Color, textColor: Color) {
    self.text = text
    self.color = color
    self.textColor = textColor
  }

  public var body: some View {
    Text(text)
      .textCase(.uppercase)
      .font(Tokens.Typography.annotationBold)
      .foregroundStyle(textColor)
      .padding(.horizontal, Tokens.Space.xs)
      .padding(.vertical, Tokens.Space.xxs)
      .background(color.opacity(Tokens.Opacity.wash), in: .rect(cornerRadius: Tokens.Radius.small))
      .background(Palette.surface.opacity(Tokens.Opacity.overlay), in: .rect(cornerRadius: Tokens.Radius.small))
      .fixedSize()
  }
}
