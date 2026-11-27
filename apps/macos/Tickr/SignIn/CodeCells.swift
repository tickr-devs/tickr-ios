import SwiftUI
import TickrDesign
import TickrKit

/// A 6-digit code as metric tiles (mockup v174): one field under the tiles takes the typing, a
/// paste and the system's one-time-code AutoFill (spaces and dashes dropped); the tiles show its
/// digits, the next one outlined. `submit` runs once all digits are in.
struct CodeCells: View {
  @Binding var code: String
  let submit: () -> Void
  @FocusState private var focused: Bool

  var body: some View {
    let digits = Array(code.filter(\.isNumber).prefix(SignInLimits.codeLength))
    ZStack {
      TextField(text: $code) { Text(L10n.SignIn.codeField) }
        .textFieldStyle(.plain)
        .textContentType(.oneTimeCode)
        #if os(iOS)
        .keyboardType(.numberPad)
        #endif
        // The tiles show the digits: the field's own text and caret are not drawn.
        .foregroundStyle(.clear)
        .tint(.clear)
        .focused($focused)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onSubmit(submit)
        .onChange(of: code) { _, typed in
          let clean = String(typed.filter(\.isNumber).prefix(SignInLimits.codeLength))
          if clean != typed { code = clean }
          if clean.count == SignInLimits.codeLength { submit() }
        }
      HStack(spacing: Tokens.Space.s) {
        ForEach(0..<SignInLimits.codeLength, id: \.self) { index in
          cell(index < digits.count ? String(digits[index]) : nil, next: focused && index == digits.count)
        }
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
    .frame(height: SignInLayout.codeCell)
    .onAppear { focused = true }
  }

  private func cell(_ digit: String?, next: Bool) -> some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    return Text(verbatim: digit ?? "")
      .font(Tokens.Typography.metric)
      .foregroundStyle(Palette.textPrimary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Palette.surfaceSunken, in: shape)
      .overlay(shape.strokeBorder(next ? Palette.accent : Palette.separator,
        lineWidth: next ? Tokens.Stroke.regular : Tokens.Stroke.thin))
  }
}

/// Under an emailed code's tiles: the time it has left, and the tries left once one was wrong.
struct CodeFacts: View {
  @Environment(SignInModel.self) private var model

  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      TimelineView(.periodic(from: .now, by: SignInLimits.tickSeconds)) { context in
        let left = model.codeSecondsLeft(at: context.date)
        if left > .zero {
          StatusPill(L10n.SignIn.expiresIn(Duration.seconds(left).formatted(.time(pattern: .minuteSecond))),
            systemImage: Self.clockSymbol, tone: .neutral)
        } else {
          StatusPill(L10n.SignIn.expired, systemImage: Self.clockSymbol, tone: .warning)
        }
      }
      if model.attemptsLeft < SignInLimits.codeAttempts {
        Badge(L10n.SignIn.attemptsLeft(model.attemptsLeft), tone: model.attemptsLeft > .zero ? .warning : .loss)
      }
      Spacer(minLength: .zero)
    }
  }

  /// SF Symbol of the expiry pill.
  static let clockSymbol = "clock"
}
