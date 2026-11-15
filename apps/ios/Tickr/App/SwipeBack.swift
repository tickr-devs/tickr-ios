import SwiftUI
import UIKit

/// The pushed screens hide the navigation bar and draw their own "‹ Home" (`BackButton`), which
/// turns off UIKit's edge swipe back. Placed behind a pushed screen (`pushedScreen`), this finds the
/// screen's own navigation controller and gives that stack's swipe a delegate of ours, so the swipe
/// works again whenever there is a screen to go back to. It overrides no UIKit method: the stack's
/// own delegate is put back when the last of our screens leaves.
struct EdgeSwipeBack: UIViewControllerRepresentable {
  func makeCoordinator() -> SwipeBackDelegate { SwipeBackDelegate() }

  func makeUIViewController(context: Context) -> Anchor { Anchor(delegate: context.coordinator) }

  func updateUIViewController(_ anchor: Anchor, context: Context) {}

  static func dismantleUIViewController(_ anchor: Anchor, coordinator: SwipeBackDelegate) {
    coordinator.detach()
  }

  /// An invisible child of the pushed screen; it reaches the stack once it is on screen.
  final class Anchor: UIViewController {
    private let swipeDelegate: SwipeBackDelegate

    init(delegate: SwipeBackDelegate) {
      swipeDelegate = delegate
      super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
      let view = UIView()
      view.isUserInteractionEnabled = false
      self.view = view
    }

    /// On every appearance, so the screen under a popped one takes the swipe back.
    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      if let navigationController {
        swipeDelegate.attach(to: navigationController)
      }
    }
  }
}

/// The edge swipe's delegate while one of our pushed screens is on top: the swipe may begin only
/// when the stack has a screen to go back to and no transition is running.
@MainActor
final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
  private weak var navigationController: UINavigationController?
  /// The stack's own delegate, put back on `detach`.
  private weak var stackDelegate: (any UIGestureRecognizerDelegate)?

  func attach(to navigationController: UINavigationController) {
    guard let swipe = navigationController.interactivePopGestureRecognizer,
      swipe.delegate !== self
    else { return }
    // A screen above handed over first: keep the stack's own delegate it saved.
    if let other = swipe.delegate as? SwipeBackDelegate {
      stackDelegate = other.stackDelegate
    } else {
      stackDelegate = swipe.delegate
    }
    self.navigationController = navigationController
    swipe.delegate = self
  }

  /// Puts the stack's own delegate back, only if the swipe is still ours.
  func detach() {
    guard let swipe = navigationController?.interactivePopGestureRecognizer,
      swipe.delegate === self
    else { return }
    swipe.delegate = stackDelegate
    navigationController = nil
  }

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let navigationController else { return false }
    return navigationController.viewControllers.count > 1
      && navigationController.transitionCoordinator == nil
  }
}
