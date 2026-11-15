import SwiftUI
import TickrDesign
import TickrKit

// The pieces of the Settings window as the design draws it (board "macOS — Settings"): a tab
// strip of thin symbols over the title bar's colour, then white cards on the pale background,
// each with its uppercase monospaced label inside, small rows and a monospaced footnote.

/// The panes of the Settings window, in the design's order.
enum SettingsTab: String, CaseIterable, Identifiable {
  case general, trading, notifications, environment, storage, advanced

  var id: String { rawValue }

  var title: LocalizedStringResource {
    switch self {
    case .general: L10n.Settings.general
    case .trading: L10n.Settings.trading
    case .notifications: L10n.Settings.notifications
    case .environment: L10n.Settings.environment
    case .storage: L10n.Settings.storage
    case .advanced: L10n.Settings.advanced
    }
  }

  /// The SF Symbols closest to the design's thin line icons, one per tab.
  static let generalSymbol = "gearshape"
  /// Symbol of the Trading tab.
  static let tradingSymbol = "chart.xyaxis.line"
  /// Symbol of the Notifications tab.
  static let notificationsSymbol = "bell"
  /// Symbol of the Environment tab.
  static let environmentSymbol = "shield"
  /// Symbol of the Storage tab.
  static let storageSymbol = "cylinder"
  /// Symbol of the Advanced tab.
  static let advancedSymbol = "slider.horizontal.3"

  var symbol: String {
    switch self {
    case .general: Self.generalSymbol
    case .trading: Self.tradingSymbol
    case .notifications: Self.notificationsSymbol
    case .environment: Self.environmentSymbol
    case .storage: Self.storageSymbol
    case .advanced: Self.advancedSymbol
    }
  }

  /// Prefix of a tab button's accessibility id.
  static let idPrefix = "settings-tab-"

  /// Accessibility id of the tab's button, for the screen tour.
  var buttonID: String { Self.idPrefix + rawValue }
}

/// The design's tab strip: a row of fixed-width buttons, a thin symbol over a small title; the
/// chosen one on the selection colour in the info blue, the rest muted. Sits on the title bar's
/// colour with a hairline under it.
struct SettingsTabBar: View {
  @Binding var selection: SettingsTab

  /// Width of one tab button, in points (the design's 86).
  static let tabWidth: CGFloat = 86
  /// Height of a tab's symbol row, in points, so every symbol sits on one line.
  static let symbolSize: CGFloat = 18
  /// Font of a tab's symbol: thin, about 17 points (title2 on the Mac), as the design's line icons.
  static let symbolFont = Font.system(.title2, weight: .light)
  /// Font of a tab's title: 11-point medium (subheadline on the Mac), the design's tab label.
  static let titleFont = Font.system(.subheadline, weight: .medium)
  var body: some View {
    HStack(spacing: Tokens.Space.xs) {
      ForEach(SettingsTab.allCases) { tab in
        let chosen = tab == selection
        Button { selection = tab } label: {
          VStack(spacing: Tokens.Space.xs) {
            Image(systemName: tab.symbol)
              .font(Self.symbolFont)
              .frame(height: Self.symbolSize)
            Text(tab.title).font(Self.titleFont).lineLimit(1)
          }
          .frame(width: Self.tabWidth)
          .padding(.vertical, Tokens.Space.s)
          .foregroundStyle(chosen ? Palette.infoText : Palette.textTertiary)
          .background(chosen ? Palette.selection : .clear,
            in: RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tab.buttonID)
        .accessibilityAddTraits(chosen ? [.isSelected, .isButton] : .isButton)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, Tokens.Space.m)
    .padding(.top, Tokens.Space.xs)
    .padding(.bottom, Tokens.Space.s)
    .background(Palette.titleBar)
    .overlay(alignment: .bottom) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
    .animation(Tokens.Motion.quick, value: selection)
  }
}

/// One section of a Settings pane as the design's card: the uppercase monospaced label inside
/// the card with an optional accessory at its right (a column legend, a badge), the rows, and an
/// optional monospaced footnote at the bottom.
struct SettingsCard<Content: View, Trailing: View>: View {
  let title: LocalizedStringResource
  let footnote: Text?
  let footnoteColor: Color
  let content: Content
  let trailing: Trailing

  init(
    _ title: LocalizedStringResource, footnote: Text? = nil, footnoteColor: Color = Palette.textQuaternary,
    @ViewBuilder content: () -> Content, @ViewBuilder trailing: () -> Trailing
  ) {
    self.title = title
    self.footnote = footnote
    self.footnoteColor = footnoteColor
    self.content = content()
    self.trailing = trailing()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack(spacing: Tokens.Space.s) {
        CardLabel(title)
        Spacer(minLength: Tokens.Space.s)
        trailing
      }
      content
      if let footnote {
        footnote
          .font(Tokens.Typography.annotation)
          .foregroundStyle(footnoteColor)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, Tokens.Space.xxs)
      }
    }
    // Fills the height it is offered, so cards side by side in a row end level.
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(Tokens.Space.l)
    .tickrCard(radius: Tokens.Radius.large)
  }
}

extension SettingsCard where Trailing == EmptyView {
  init(
    _ title: LocalizedStringResource, footnote: Text? = nil, footnoteColor: Color = Palette.textQuaternary,
    @ViewBuilder content: () -> Content
  ) {
    self.init(title, footnote: footnote, footnoteColor: footnoteColor, content: content) { EmptyView() }
  }
}

/// A row of a Settings card: the label in the secondary text colour, the value at the trailing
/// edge in monospace (the board's key–value rows).
struct SettingsRow<Value: View>: View {
  let label: Text
  let value: Value

  init(_ label: LocalizedStringResource, @ViewBuilder value: () -> Value) {
    self.label = Text(label)
    self.value = value()
  }

  init(_ label: Text, @ViewBuilder value: () -> Value) {
    self.label = label
    self.value = value()
  }

  var body: some View {
    // The value keeps one line; a long label wraps instead, as on the board.
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      label
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Tokens.Space.m)
      value
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(Palette.textPrimary)
        .lineLimit(1)
        .fixedSize()
    }
    .accessibilityElement(children: .combine)
  }
}

extension SettingsRow where Value == Text {
  /// A row whose value is data or an already localized word.
  init(_ label: LocalizedStringResource, value: String) {
    self.init(label) { Text(verbatim: value) }
  }
}

/// A switch that only shows a value of the bot's configuration: the design's switch drawn on, in
/// the accent, or off; it never edits anything.
struct ConfigSwitch: View {
  let on: Bool

  /// Size of the switch and its knob, in points (the design's 34 × 20 with a 16-point knob).
  static let width: CGFloat = 34
  static let height: CGFloat = 20
  static let knob: CGFloat = 16

  var body: some View {
    Capsule()
      .fill(on ? Palette.accent : Palette.separatorStrong)
      .frame(width: Self.width, height: Self.height)
      .overlay(alignment: on ? .trailing : .leading) {
        Circle().fill(Palette.surface)
          .frame(width: Self.knob, height: Self.knob)
          .padding(Tokens.Space.xxs)
      }
      .accessibilityHidden(true)
  }
}

/// A switch of the app's own preferences with its title, in the design's switch colours.
struct SwitchRow: View {
  let title: LocalizedStringResource
  @Binding var isOn: Bool

  init(_ title: LocalizedStringResource, isOn: Binding<Bool>) {
    self.title = title
    self._isOn = isOn
  }

  var body: some View {
    // The switch first, then its title, as on the board.
    HStack(spacing: Tokens.Space.m) {
      Toggle(isOn: $isOn) { Text(title) }
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(Palette.accent)
      Text(title)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
        .accessibilityHidden(true)
    }
  }
}

/// The design's segmented strip: the choices side by side on the sunken surface, the chosen one
/// raised on the card colour with a hairline.
struct SegmentStrip<Value: Hashable, Label: View>: View {
  @Binding var selection: Value
  let choices: [Value]
  let label: (Value) -> Label

  init(selection: Binding<Value>, choices: [Value], @ViewBuilder label: @escaping (Value) -> Label) {
    self._selection = selection
    self.choices = choices
    self.label = label
  }

  var body: some View {
    HStack(spacing: Tokens.Space.xs) {
      ForEach(choices, id: \.self) { choice in
        let chosen = choice == selection
        Button { selection = choice } label: {
          label(choice)
            .font(Tokens.Typography.buttonCompact)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.s)
            .foregroundStyle(chosen ? Palette.textPrimary : Palette.textTertiary)
            .background {
              if chosen {
                RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
                  .fill(Palette.surface)
                  .strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin)
              }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? [.isSelected, .isButton] : .isButton)
      }
    }
    .padding(Tokens.Space.xs)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
      .strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
    .animation(Tokens.Motion.quick, value: selection)
  }
}

/// A small tile on the sunken surface: a figure in bold monospace over its label (History), or a
/// dot, a label and a figure on one line (the bot's status timing).
struct StatTile: View {
  let value: String
  let label: LocalizedStringResource
  let dot: Color?

  init(value: String, label: LocalizedStringResource) {
    self.value = value
    self.label = label
    self.dot = nil
  }

  init(dot: Color, label: LocalizedStringResource, value: String) {
    self.value = value
    self.label = label
    self.dot = dot
  }

  var body: some View {
    Group {
      if let dot {
        HStack(spacing: Tokens.Space.s) {
          PulseDot(dot, pulsing: false)
          Text(label)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textSecondary)
          Spacer(minLength: Tokens.Space.s)
          Text(verbatim: value)
            .font(Tokens.Typography.calloutMono.weight(.bold))
            .foregroundStyle(Palette.textPrimary)
        }
      } else {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
          Text(verbatim: value)
            .font(Tokens.Typography.metric)
            .foregroundStyle(Palette.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(Tokens.Shrink.standard)
          Text(label)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textTertiary)
            .lineLimit(1)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
      .strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
    .accessibilityElement(children: .combine)
  }
}
