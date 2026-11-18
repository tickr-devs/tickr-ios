import AppKit
import SwiftUI
import TickrDesign

/// The main window fits the screen it is on (owner decision 2026-11-16, option A "Окно под экран").
///
/// The window's comfortable least size (`TickrMacApp.leastWidth`, `minHeight`: no screen cut, the
/// title bar's line whole) can be larger than a small display (a 1280 × 800 laptop, a 1024 × 768
/// display). A least size larger than the screen put the right of the window, and with it the
/// Overview's Safety · bot commands, out of reach. So the least size is capped to the room the
/// screen's visible area leaves the window's content; the screens then fit that room themselves
/// (`ScreenRoomFrame`): Overview stacks its cards, the others scroll. Every number here comes from the
/// screen and the window, never from a layout pass, so the least size changes only when the window
/// moves to another screen or a display changes, never during a resize.
enum WindowFit {
  /// The window's least content size on a screen that leaves `room` for its content: the
  /// comfortable least size, each side capped to the room. Without a screen yet (`room` nil) the
  /// comfortable size holds.
  static func least(comfortable: CGSize, room: CGSize?) -> CGSize {
    guard let room else { return comfortable }
    return CGSize(width: min(comfortable.width, room.width), height: min(comfortable.height, room.height))
  }

  /// The room a screen's visible area (`visible`, menu bar and Dock left out) leaves the content
  /// of a window whose title bar and toolbar take `chrome` points of its height.
  static func room(visible: CGSize, chrome: CGFloat) -> CGSize {
    CGSize(width: max(visible.width, 0), height: max(visible.height - chrome, 0))
  }

  /// `frame` shrunk to `visible` where it is larger and moved inside it, so no part of the window
  /// is off the screen; a frame already inside is returned as it is.
  static func fitted(_ frame: CGRect, in visible: CGRect) -> CGRect {
    let width = min(frame.width, visible.width)
    let height = min(frame.height, visible.height)
    let x = min(max(frame.minX, visible.minX), visible.maxX - width)
    let y = min(max(frame.minY, visible.minY), visible.maxY - height)
    return CGRect(x: x, y: y, width: width, height: height)
  }

  /// The visible area of the screen `window` is on (the main screen while it is on none yet).
  @MainActor
  static func visibleFrame(of window: NSWindow) -> CGRect? {
    guard var visible = (window.screen ?? NSScreen.main)?.visibleFrame else { return nil }
    #if DEBUG
    // UI tests and the layout sweep pretend a smaller display (`LayoutSweep.screenKey`); the
    // Mac's own display settings are never changed.
    if let pretended = LayoutSweep.pretendedScreen {
      visible.size = CGSize(width: min(visible.width, pretended.width), height: min(visible.height, pretended.height))
    }
    #endif
    return visible
  }

  /// The room the screen `window` is on leaves the window's content: its visible area less the
  /// window's title bar and toolbar.
  @MainActor
  static func room(of window: NSWindow) -> CGSize? {
    guard let visible = visibleFrame(of: window) else { return nil }
    return room(visible: visible.size, chrome: window.frame.height - window.contentLayoutRect.height)
  }
}

/// Reports the room the window's screen leaves its content (`WindowFit.room(of:)`) when the view
/// joins a window, when the window moves to another screen or becomes key, and when a display
/// changes; on joining and on a display change it also moves and shrinks the window into the
/// screen's visible area (once its least size allows it).
struct ScreenRoomReader: NSViewRepresentable {
  let changed: (CGSize) -> Void

  func makeNSView(context: Context) -> RoomView {
    RoomView(changed: changed)
  }

  func updateNSView(_ view: RoomView, context: Context) {
    view.changed = changed
  }

  final class RoomView: NSView {
    var changed: (CGSize) -> Void
    private var observers: [NSObjectProtocol] = []

    init(changed: @escaping (CGSize) -> Void) {
      self.changed = changed
      super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    isolated deinit {
      observers.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
      guard let window else { return }
      let center = NotificationCenter.default
      for name in [NSWindow.didChangeScreenNotification, NSWindow.didBecomeKeyNotification] {
        observers.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated { self?.report(fits: false) }
        })
      }
      observers.append(center.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.report(fits: true) }
      })
      // After the window's first layout, when its title bar and toolbar are in place.
      Task { @MainActor [weak self] in self?.report(fits: true) }
    }

    /// Times the window is moved into the screen, and seconds between them: SwiftUI takes the
    /// lower least size a frame or two after the room is reported, and until then it may hold
    /// the window at the old least size.
    static let fitAttempts = 10
    static let fitRetrySeconds = 0.05

    /// Reports the room; with `fits`, then moves the window into the screen's visible area.
    private func report(fits: Bool) {
      guard let window, let room = WindowFit.room(of: window) else { return }
      changed(room)
      if fits { fit(attempt: 1) }
    }

    /// Moves and shrinks the window into the screen's visible area, again after a pause while
    /// it does not hold there, at most `fitAttempts` times.
    private func fit(attempt: Int) {
      Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(Self.fitRetrySeconds))
        guard let self, let window, let visible = WindowFit.visibleFrame(of: window) else { return }
        let fitted = WindowFit.fitted(window.frame, in: visible)
        guard fitted != window.frame else { return }
        window.setFrame(fitted, display: true)
        if attempt < Self.fitAttempts { fit(attempt: attempt + 1) }
      }
    }
  }
}

/// A screen in the room the window leaves it, at least `least` large: when the room is smaller
/// (the window capped to a small display, `WindowFit`), the screen keeps its least size and
/// scrolls; otherwise it takes the room exactly and nothing scrolls. Overview's least width is
/// one column of cards (`OverviewView.leastSize`), so it never scrolls sideways: its cards stack.
struct ScreenRoomFrame: ViewModifier {
  let least: CGSize

  func body(content: Content) -> some View {
    GeometryReader { room in
      ScrollView([.horizontal, .vertical]) {
        content
          // The screens' own scroll views keep their usual bounce.
          .scrollBounceBehavior(.automatic, axes: [.horizontal, .vertical])
          .frame(width: max(room.size.width, least.width), height: max(room.size.height, least.height),
            alignment: .topLeading)
      }
      .scrollEdgeHints()
      // A screen that fits its room neither scrolls nor bounces here.
      .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
    }
  }
}
