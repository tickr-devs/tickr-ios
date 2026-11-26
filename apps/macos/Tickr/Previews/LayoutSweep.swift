#if DEBUG && os(macOS)
import AppKit
import SwiftUI
import TickrKit

/// Layout sweep: with `sweepKey` set (and the fixtures, `PreviewAPI.fixturesKey`), the app walks
/// every screen at each window size in `sizes`, with the Chart's inspector and every study off and on, keeps
/// a picture of the whole window (title bar and toolbar included) for each, then drags the window
/// through every size between the largest and the smallest on every screen, and exits 0. A layout
/// that cannot settle (AppKit's "Update Constraints in Window" loop) crashes the app instead, so
/// a non-zero exit fails the run. `apps/macos/scripts/layout-sweep.sh` runs it in English and
/// Spanish; CI keeps the pictures. Debug builds only.
///
/// The pictures are drawn by the window itself (`cacheDisplay`), so the sweep needs no Screen
/// Recording permission and works on a window larger than the display.
@MainActor
enum LayoutSweep {
  /// Environment variable naming the folder the pictures go to.
  static let sweepKey = "TICKR_LAYOUT_SWEEP"
  /// File naming the sizes left out because the window cannot be that small.
  static let skippedFile = "skipped-sizes.txt"
  /// File written into the folder once every picture is taken and every size held.
  static let doneFile = "done"
  /// Extension of a picture.
  static let pictureExtension = "png"
  /// Separates the parts of a picture's name: `<width>x<height>-<section>[-inspector]`.
  static let separator = "-"
  static let times = "x"
  /// Name part of a picture with the Chart's inspector open.
  static let inspectorSuffix = "inspector"
  /// Name part of the window filling the display's visible area (as Zoom makes it).
  static let zoomedName = "zoomed"

  /// Window sizes pictured, in points: the smallest the app allows (`least`, which follows the
  /// title bar's data), the size it first opens at, then the common laptop and desktop widths.
  /// The display's whole visible area (`zoomedName`) is added at run time.
  static func sizes(least: CGSize) -> [CGSize] {
    [least, CGSize(width: TickrMacApp.defaultWidth, height: TickrMacApp.defaultHeight), small, laptop, desktop, large]
  }
  /// A 1024 × 768 display, a 13-inch laptop, a 15-inch laptop and a 16-inch laptop, in points.
  /// A size under the window's least one is left out at run time and named in `skippedFile`.
  static let small = CGSize(width: 1024, height: 768)
  static let laptop = CGSize(width: 1280, height: 800)
  static let desktop = CGSize(width: 1440, height: 900)
  static let large = CGSize(width: 1728, height: 1080)
  /// Seconds a screen gets to load its data and finish its entrance animations before a picture.
  static let settleSeconds: Double = 2
  /// Seconds the app gets to open its window and read the fixtures before the sweep starts.
  static let startSeconds: Double = 3
  /// Points the window shrinks by per step of the drag, and seconds between steps (about one
  /// frame, so each size gets a full layout pass, as a live resize does).
  static let dragStep: CGFloat = 16
  static let dragStepSeconds: Double = 0.02

  /// Environment variable that opens the main window at the app's least size, in the screen's
  /// visible area: the UI tests of the narrowest window (OverviewCommandsUITests), where dragging
  /// a window's edge is unreliable.
  static let smallestKey = "TICKR_SMALLEST_WINDOW"
  /// Environment variable that opens Overview scrolled so the Safety · bot card is at its top:
  /// UI tests click its commands there, never after a scroll, and away from the screen's bottom
  /// edge (where a hidden Dock rises over a click).
  static let safetyFirstKey = "TICKR_OVERVIEW_SAFETY_FIRST"
  static var safetyFirst: Bool { ProcessInfo.processInfo.environment[safetyFirstKey] != nil }
  /// Seconds between looks for the main window while it opens.
  static let windowPollSeconds = 0.1
  /// Environment variable that makes the app take its display's visible area as at most this
  /// many points, `<width>x<height>` (for example `1024x768`): the UI tests of a small display
  /// (OverviewCommandsUITests), which never change the Mac's own display settings. The window's
  /// least size is capped to it and the window moved into it as on such a display (`WindowFit`).
  static let screenKey = "TICKR_SCREEN"
  /// Parts of a `<width>x<height>` size.
  static let sizeParts = 2
  /// The display size `screenKey` pretends, nil when it is not set or not `<width>x<height>`.
  static var pretendedScreen: CGSize? {
    guard let text = ProcessInfo.processInfo.environment[screenKey] else { return nil }
    let parts = text.split(separator: Character(times)).compactMap { Double($0) }
    guard parts.count == sizeParts, let width = parts.first, let height = parts.last else { return nil }
    return CGSize(width: width, height: height)
  }

  /// Sets the main window to the app's least size when the app was launched with `smallestKey`,
  /// once the status is read (the least width holds the title bar's line, which shows it).
  static func smallestIfAsked(model: AppModel) {
    guard ProcessInfo.processInfo.environment[smallestKey] != nil else { return }
    Task { @MainActor in
      while mainWindow() == nil || model.status == nil {
        try? await Task.sleep(for: .seconds(windowPollSeconds))
      }
      if let window = mainWindow() {
        resize(window, to: least(model))
      }
    }
  }

  /// The main window's least size for the data shown now (`TickrMacApp.leastWidth`), capped to
  /// the room its screen leaves it (`WindowFit`), as the window itself takes it.
  static func least(_ model: AppModel) -> CGSize {
    let comfortable = CGSize(
      width: TickrMacApp.leastWidth(model: model, chart: Container.shared.chartModel()), height: TickrMacApp.minHeight)
    return WindowFit.least(comfortable: comfortable, room: mainWindow().flatMap(WindowFit.room(of:)))
  }

  /// Starts the sweep when the app was launched with `sweepKey` set.
  static func startIfAsked(model: AppModel) {
    guard let path = ProcessInfo.processInfo.environment[sweepKey] else { return }
    let folder = URL(fileURLWithPath: path, isDirectory: true)
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(startSeconds))
      await run(model: model, into: folder)
      FileManager.default.createFile(atPath: folder.appending(path: doneFile).path, contents: nil)
      exit(EXIT_SUCCESS)
    }
  }

  private static func run(model: AppModel, into folder: URL) async {
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    guard let window = mainWindow() else {
      exit(EXIT_FAILURE)
    }
    let smallest = least(model)
    var named = sizes(least: smallest).map { (name(of: $0), $0) }
    if let visible = window.screen?.visibleFrame.size { named.append((zoomedName, visible)) }
    // A size under the window's least one cannot be had (AppKit would keep the least size and
    // the picture would carry a wrong name): it is left out and named in `skippedFile`.
    let skipped = named.filter { !allowed($0.1, least: smallest) }
    named.removeAll { !allowed($0.1, least: smallest) }
    note(skipped, in: folder)
    for (wanted, size) in named {
      resize(window, to: size)
      // The least size is the content's; AppKit adds the title bar to it, so that picture is named
      // by the window's own size.
      let sizeName = wanted == name(of: smallest) ? name(of: window.frame.size) : wanted
      for section in AppSection.allCases {
        for inspector in section == .chart ? [false, true] : [false] {
          fullChart(inspector)
          model.section = section
          try? await Task.sleep(for: .seconds(settleSeconds))
          var parts = [sizeName, section.rawValue]
          if inspector { parts.append(inspectorSuffix) }
          picture(of: window, to: folder.appending(path: parts.joined(separator: separator))
            .appendingPathExtension(pictureExtension))
        }
      }
    }
    fullChart(false)
    let largest = named.map(\.1).max { $0.width * $0.height < $1.width * $1.height } ?? window.frame.size
    for section in AppSection.allCases {
      for inspector in section == .chart ? [false, true] : [false] {
        fullChart(inspector)
        model.section = section
        await drag(window, from: largest, to: smallest)
      }
    }
    fullChart(false)
  }

  /// Shrinks the window step by step from `largest` to the app's smallest size and back.
  private static func drag(_ window: NSWindow, from largest: CGSize, to smallest: CGSize) async {
    let steps = Int(max(largest.width - smallest.width, largest.height - smallest.height) / dragStep)
    let path = (0...steps) + (0...steps).reversed()
    for step in path {
      let shrink = CGFloat(step) * dragStep
      let size = CGSize(width: max(smallest.width, largest.width - shrink),
        height: max(smallest.height, largest.height - shrink))
      resize(window, to: size)
      try? await Task.sleep(for: .seconds(dragStepSeconds))
    }
  }

  /// The Chart's settings the sweep turns on together with the inspector: every study pane and
  /// line, the state that once looped AppKit's layout until the app crashed.
  static let fullChartKeys = [
    ChartView.Keys.decisions, ChartView.Keys.movingAverages, ChartView.Keys.bollinger,
    ChartView.Keys.macd, ChartView.Keys.rsi, ChartView.Keys.stochastic, ChartView.Keys.atr,
  ]

  /// The inspector with every study (`on`), or the inspector and the studies off.
  private static func fullChart(_ on: Bool) {
    for key in fullChartKeys { UserDefaults.standard.set(on, forKey: key) }
  }

  /// Whether the window can take `size`: never under its least size.
  private static func allowed(_ size: CGSize, least: CGSize) -> Bool {
    size.width >= least.width && size.height >= least.height
  }

  /// Writes the sizes left out, one "name width×height" per line, so the run reports them.
  private static func note(_ skipped: [(String, CGSize)], in folder: URL) {
    guard !skipped.isEmpty else { return }
    let lines = skipped.map { "\($0.0) \(name(of: $0.1))" }.joined(separator: Format.lineSeparator)
    try? lines.write(to: folder.appending(path: skippedFile), atomically: true, encoding: .utf8)
  }

  /// The main window (the SwiftUI scene `WindowID.main`).
  private static func mainWindow() -> NSWindow? {
    NSApp.windows.first { $0.identifier?.rawValue.hasPrefix(WindowID.main) == true }
      ?? NSApp.windows.first { $0.isVisible && $0.styleMask.contains(.titled) }
  }

  private static func resize(_ window: NSWindow, to size: CGSize) {
    let origin = window.screen?.visibleFrame.origin ?? .zero
    window.setFrame(CGRect(origin: origin, size: size), display: true)
  }

  private static func name(of size: CGSize) -> String {
    "\(Int(size.width))\(times)\(Int(size.height))"
  }

  /// The whole window as drawn, title bar and toolbar included, written as PNG.
  private static func picture(of window: NSWindow, to file: URL) {
    guard let view = window.contentView?.superview ?? window.contentView,
      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    try? bitmap.representation(using: .png, properties: [:])?.write(to: file)
  }
}
#endif
