import Network
import SwiftUI
import TickrDesign
import TickrKit

/// Sizes of the sign-in screens (mockup v174, boards MacSignIn, IOSSignIn and IPadSignIn).
enum SignInLayout {
  /// The Mac's and iPad's brand column.
  static let brandColumn: CGFloat = 400
  /// The form's width beside it.
  static let formWidth: CGFloat = 380
  /// The form's distance from the window's top beside the brand column.
  static let formTop: CGFloat = 56
  /// One code cell's height (the metric tiles of the code steps).
  static let codeCell: CGFloat = 52
  /// The least height of a field, a button and a footer row: the Mac's icon button; the iPhone's
  /// and iPad's touch target (Apple HIG, owner: 44 pt on iPad too).
  #if os(macOS)
  static let control: CGFloat = Tokens.Size.iconButton
  #else
  static let control: CGFloat = Tokens.Size.touchTarget
  #endif
}

/// The sign-in with the owner's tickr.bot account, shown while this device has no sign-in with
/// the bot (`SignInState`). One screen for the three devices, laid out as each one's board: the
/// iPhone's single column with the wordmark over the title; the Mac's and iPad's two columns,
/// the wordmark alone in the left panel and the form on the right (mockup v191, boards MacSignIn,
/// IPadSignIn). The status pill says whether this device has a network path to api.tickr.bot.
/// `markShown` hides the wordmark while the launch's opening flies its own there; `markMoved`
/// reports where it is (global coordinates).
public struct SignInScreen: View {
  @State private var model: SignInModel
  @State private var online = true
  let markShown: Bool
  let markMoved: (CGPoint) -> Void

  public init(
    device: SignInDevice, ended: SignInEnd?, markShown: Bool = true, markMoved: @escaping (CGPoint) -> Void = { _ in }
  ) {
    _model = State(initialValue: SignInModel(device: device, ended: ended))
    self.markShown = markShown
    self.markMoved = markMoved
  }

  /// The height of the wordmark the launch's opening lands on, for `device`.
  public static func markHeight(on device: SignInDevice) -> CGFloat {
    device == .iPhone ? Tokens.Size.wordmark : Tokens.Size.wordmarkLaunch
  }

  public var body: some View {
    Group {
      if model.device == .iPhone {
        column
      } else {
        columns
      }
    }
    .background(background)
    .keepsContentOffline()
    .environment(model)
    .task {
      for await path in NWPathMonitor() {
        online = path.status == .satisfied
      }
    }
  }

  /// The screen's background: on iPhone and iPad also under the status bar and the home
  /// indicator. On the Mac it stays inside the content area under the title bar, as every screen's
  /// root does: the window's least size is worked out from that area (`WindowFit.room`).
  @ViewBuilder private var background: some View {
    #if os(macOS)
    Palette.background
    #else
    Palette.background.ignoresSafeArea()
    #endif
  }

  // MARK: Layouts

  private var column: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Tokens.Space.l) {
        if model.step == .main {
          mark(height: Self.markHeight(on: .iPhone))
          SignInHeading(title: Text(L10n.SignIn.title), line: Text(L10n.SignIn.line))
        } else {
          SignInStepHeading()
        }
        SignInForm()
      }
      .padding(.horizontal, Tokens.Space.l)
      .padding(.vertical, Tokens.Space.xl)
    }
    .scrollEdgeHints()
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) { statusPill.padding(.bottom, Tokens.Space.s) }
  }

  private var columns: some View {
    HStack(spacing: .zero) {
      mark(height: Self.markHeight(on: model.device))
        .frame(width: SignInLayout.brandColumn)
        .frame(maxHeight: .infinity)
        .background(Palette.surface)
        .overlay(alignment: .trailing) { Rectangle().fill(Palette.separator).frame(width: Tokens.Stroke.thin) }
      ScrollView {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
          if model.step == .main {
            SignInHeading(title: Text(L10n.SignIn.title), line: Text(L10n.SignIn.line))
          } else {
            SignInStepHeading()
          }
          SignInForm()
        }
        .frame(maxWidth: SignInLayout.formWidth)
        .padding(.top, SignInLayout.formTop)
        .padding(.horizontal, Tokens.Space.l)
        .frame(maxWidth: .infinity)
      }
      .scrollEdgeHints()
      .safeAreaInset(edge: .bottom) { statusPill.padding(.bottom, Tokens.Space.l) }
    }
  }

  // MARK: Pieces

  private func mark(height: CGFloat) -> some View {
    Wordmark(height: height)
      .accessibilityAddTraits(.isHeader)
      .opacity(markShown ? 1 : 0)
      .onGeometryChange(for: CGPoint.self) { proxy in
        let frame = proxy.frame(in: .global)
        return CGPoint(x: frame.midX, y: frame.midY)
      } action: { centre in
        if !markShown { markMoved(centre) }
      }
  }

  private var statusPill: some View {
    let state = String(localized: online ? L10n.SignIn.online : L10n.SignIn.offline)
    return StatusPill(keepingCase: Text(L10n.SignIn.status(BotAddress.url.host() ?? "", state)),
      tone: online ? .profit : .warning)
      .frame(maxWidth: .infinity)
  }
}

/// The title and line over a step.
struct SignInHeading: View {
  /// Accessibility id of the title (the UI tests find the sign-in by it).
  static let titleID = "sign-in-title"
  let title: Text
  let line: Text

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      title
        .font(Tokens.Typography.title)
        .foregroundStyle(Palette.textPrimary)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(Self.titleID)
      line
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

/// A step under the sign-in: our back capsule (never the system's), then the step's title and line.
struct SignInStepHeading: View {
  @Environment(SignInModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.l) {
      Button { model.back() } label: {
        BackCapsule(model.step == .recovery ? L10n.SignIn.backTwoStep : L10n.SignIn.backSignIn)
      }
      .buttonStyle(.backCapsule)
      .keyboardShortcut(.cancelAction)
      SignInHeading(title: Text(title), line: line)
    }
  }

  private var title: LocalizedStringResource {
    switch model.step {
    case .code, .sent: L10n.SignIn.codeTitle
    case .twoStep, .recovery: L10n.SignIn.twoTitle
    case .forgot: L10n.SignIn.forgotTitle
    case .main: L10n.SignIn.title
    }
  }

  private var line: Text {
    switch model.step {
    case .code: Text(L10n.SignIn.codePrompt(model.email))
    case .twoStep: Text(L10n.SignIn.twoPrompt)
    case .recovery: Text(L10n.SignIn.recoveryPrompt)
    case .forgot: Text(L10n.SignIn.forgotPrompt)
    case .sent: Text(L10n.SignIn.sentPrompt(model.email))
    case .main: Text(L10n.SignIn.line)
    }
  }
}

/// The banner of the last problem, if any, then the step's card.
struct SignInForm: View {
  @Environment(SignInModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.l) {
      if let problem = model.problem {
        WarningBanner(problem.title, detail: problem.detail(on: model.device), systemImage: problem.symbol,
          tone: problem.tone)
          .transition(.opacity)
      }
      SignInCard()
    }
    .animation(Tokens.Motion.quick, value: model.problem)
    .animation(Tokens.Motion.standard, value: model.step)
  }
}

#Preview {
  SignInScreen(device: .iPhone, ended: .revoked)
}
