import SwiftUI
import TickrDesign
import TickrKit

/// Sizes of the notifications screen (mockup v189, board PushAsk).
enum NotificationsAskLayout {
  /// The bell's round well: the iPhone's screen, and the sheet of the Mac and the wide iPad.
  static let well: CGFloat = 72
  static let wellSheet: CGFloat = 56
  /// The bell inside it.
  static let bell: CGFloat = 34
  static let bellSheet: CGFloat = 26
  /// The sheet's width on the Mac and the wide iPad.
  static let sheetWidth: CGFloat = 440
  /// The least height of the buttons: the Mac's icon button; the iPhone's and iPad's touch target.
  #if os(macOS)
  static let control: CGFloat = Tokens.Size.iconButton
  #else
  static let control: CGFloat = Tokens.Size.touchTarget
  #endif
  /// Symbols of the bell and the reasons.
  static let bellSymbol = "bell.fill"
  static let alarmsSymbol = "exclamationmark.shield.fill" // symbol: an alarm (a stop or the bot), not a stop's state
  static let signInsSymbol = "key.fill"
  static let liveActivitySymbol = "iphone"
}

/// "Turn on notifications" (mockup v189, board PushAsk): why the app asks, before the system does.
/// The iPhone's own screen (`sheet` false) ends with the two buttons stacked and lists the Live
/// Activity; the Mac's and the wide iPad's sheet puts the buttons side by side. The model is
/// `NotificationPermission`, from the environment.
public struct NotificationsAsk: View {
  @Environment(NotificationPermission.self) private var permission
  let sheet: Bool
  let liveActivity: Bool

  public init(sheet: Bool, liveActivity: Bool) {
    self.sheet = sheet
    self.liveActivity = liveActivity
  }

  public var body: some View {
    Group {
      if sheet {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
          heading
          reasons
          foot.multilineTextAlignment(.leading)
          HStack(spacing: Tokens.Space.s) {
            Spacer(minLength: .zero)
            notNowButton
            allowButton
          }
        }
        .padding(Tokens.Space.xl)
        .frame(width: NotificationsAskLayout.sheetWidth)
      } else {
        VStack(spacing: Tokens.Space.l) {
          ScrollView {
            VStack(spacing: Tokens.Space.l) {
              heading
              reasons
            }
            .padding(.top, Tokens.Space.xxl)
          }
          .scrollEdgeHints()
          allowButton
          notNowButton
          foot
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.bottom, Tokens.Space.l)
      }
    }
    .background { Palette.background.ignoresSafeArea() }
    .interactiveDismissDisabled()
  }

  private var heading: some View {
    VStack(spacing: Tokens.Space.m) {
      Image(systemName: NotificationsAskLayout.bellSymbol)
        .font(.system(size: sheet ? NotificationsAskLayout.bellSheet : NotificationsAskLayout.bell))
        .foregroundStyle(Palette.warningText)
        .frame(width: well, height: well)
        .background(Circle().fill(Palette.warning.opacity(Tokens.Opacity.glow)))
        .accessibilityHidden(true)
      Text(L10n.Notifications.title)
        .font(Tokens.Typography.title)
        .foregroundStyle(Palette.textPrimary)
        .accessibilityAddTraits(.isHeader)
      Text(L10n.Notifications.lead)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var well: CGFloat { sheet ? NotificationsAskLayout.wellSheet : NotificationsAskLayout.well }

  private var reasons: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      NotificationsReason(NotificationsAskLayout.alarmsSymbol, tone: .loss,
        title: L10n.Notifications.alarms, line: L10n.Notifications.alarmsLine)
      NotificationsReason(NotificationsAskLayout.signInsSymbol, tone: .info,
        title: L10n.Notifications.signIns, line: L10n.Notifications.signInsLine)
      if liveActivity {
        NotificationsReason(NotificationsAskLayout.liveActivitySymbol, tone: .accent,
          title: L10n.Notifications.liveActivity, line: L10n.Notifications.liveActivityLine)
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
        .strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin)
    }
  }

  private var allowButton: some View {
    Button {
      Task { await permission.allow() }
    } label: {
      Label { Text(L10n.Notifications.allow) } icon: { Image(systemName: NotificationsAskLayout.bellSymbol) }
        .frame(maxWidth: sheet ? nil : .infinity, minHeight: NotificationsAskLayout.control)
    }
    .buttonStyle(.action(.primary))
    .keyboardShortcut(.defaultAction)
  }

  private var notNowButton: some View {
    Button {
      permission.notNow()
    } label: {
      Text(L10n.Notifications.notNow)
        .frame(maxWidth: sheet ? nil : .infinity, minHeight: NotificationsAskLayout.control)
    }
    .buttonStyle(.action(sheet ? .secondary : .ghost))
    .keyboardShortcut(.cancelAction)
  }

  private var foot: some View {
    Text(L10n.Notifications.foot)
      .font(Tokens.Typography.caption)
      .foregroundStyle(Palette.textTertiary)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
  }
}

/// One reason on the notifications screen: its symbol on a tinted tile, the title and its line.
struct NotificationsReason: View {
  let symbol: String
  let tone: Tone
  let title: LocalizedStringResource
  let line: LocalizedStringResource

  init(_ symbol: String, tone: Tone, title: LocalizedStringResource, line: LocalizedStringResource) {
    self.symbol = symbol
    self.tone = tone
    self.title = title
    self.line = line
  }

  var body: some View {
    HStack(alignment: .top, spacing: Tokens.Space.m) {
      Image(systemName: symbol)
        .font(Tokens.Typography.symbolCompact)
        .foregroundStyle(tone.text)
        .frame(width: Tokens.Size.iconButtonCompact, height: Tokens.Size.iconButtonCompact)
        .background(tone.fill.opacity(Tokens.Opacity.glow),
          in: RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        Text(title)
          .font(Tokens.Typography.symbol)
          .foregroundStyle(Palette.textPrimary)
        Text(line)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textSecondary)
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  NotificationsAsk(sheet: false, liveActivity: true)
    .environment(NotificationPermission(enabled: false))
}

#Preview {
  NotificationsAsk(sheet: true, liveActivity: false)
    .environment(NotificationPermission(enabled: false))
}
