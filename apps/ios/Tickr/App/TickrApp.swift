import SwiftUI
import TickrDesign
import TickrKit
import TickrScreens

@main
struct TickrApp: App {
  /// Registers for the bot's push and reports the tokens (PhoneAppDelegate.swift).
  @UIApplicationDelegateAdaptor(PhoneAppDelegate.self) private var appDelegate
  @State private var model = Container.shared.appModel()
  /// Until the opening animation has handed the launch screen over to Home.
  @State private var opening = true
  /// Until the flying mark has landed in Home's title: Home's cards wait to rise until then.
  @State private var landed = false

  var body: some Scene {
    WindowGroup {
      PhoneSignInGate(opening: opening)
        .withoutScrollIndicators()
        .environment(\.risesHeld, !landed)
        .overlay {
          if opening { LaunchHandoff { landed = true } finished: { opening = false } }
        }
        .readFailureContext(model)
        .environment(model)
        .tint(Palette.info)
    }
  }
}

/// The app's screens once the phone is signed in with the bot, the sign-in until then (mockup
/// v174, boards IOSSignIn and IPadSignIn: the iPad takes the Mac's sign-in at touch sizes). The
/// demo day and a development address need no sign-in. The launch's opening lands on the
/// sign-in's mark when there is no sign-in, else on Home's.
private struct PhoneSignInGate: View {
  @Environment(AppModel.self) private var model
  @State private var state = Container.shared.signInState()
  let opening: Bool

  var body: some View {
    Group {
      if model.connection.needsSignIn {
        let device = SignInDevice.current
        SignInScreen(device: device, ended: state.ended, markShown: !opening) { centre in
          model.homeMarkCentre = centre
          model.homeMarkSide = SignInScreen.markSide(on: device)
        }
      } else {
        AdaptiveRoot()
      }
    }
    .onChange(of: state.signedIn) { _, signedIn in model.connection = model.connection.signedIn(signedIn) }
  }
}
