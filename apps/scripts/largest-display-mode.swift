// Sets every active display to its largest mode usable for the desktop, and prints each display's
// mode before and after. A CI macOS runner starts at 1024 x 768 points, smaller than the macOS
// app's least window (TickrMacApp.leastWidth / minHeight), so a UI test there would find controls
// off screen. Run before the UI tests: `swift apps/scripts/largest-display-mode.swift`.
// It changes the display permanently, so it refuses to run anywhere but a GitHub Actions runner
// (`GITHUB_ACTIONS` is "true" there): never on the owner's Mac.
import CoreGraphics
import Foundation

/// The variable GitHub Actions sets to "true" on its runners, read by name only.
let actionsKey = "GITHUB_ACTIONS"
guard ProcessInfo.processInfo.environment[actionsKey] == "true" else {
  FileHandle.standardError.write(Data("refused: only for a GitHub Actions runner (\(actionsKey) is not true)\n".utf8))
  exit(2)
}

var count: UInt32 = 0
CGGetActiveDisplayList(0, nil, &count)
var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
CGGetActiveDisplayList(count, &displays, &count)
let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary

func describe(_ mode: CGDisplayMode?) -> String {
  guard let mode else { return "none" }
  return "\(mode.width) x \(mode.height) points, \(mode.pixelWidth) x \(mode.pixelHeight) pixels"
}

for display in displays {
  print("display \(display): now \(describe(CGDisplayCopyDisplayMode(display)))")
  let modes = (CGDisplayCopyAllDisplayModes(display, options) as? [CGDisplayMode] ?? [])
    .filter { $0.isUsableForDesktopGUI() }
  for mode in modes { print("  offers \(describe(mode))") }
  guard let largest = modes.max(by: { $0.width * $0.height < $1.width * $1.height }) else { continue }
  var config: CGDisplayConfigRef?
  CGBeginDisplayConfiguration(&config)
  CGConfigureDisplayWithDisplayMode(config, display, largest, nil)
  let result = CGCompleteDisplayConfiguration(config, .permanently)
  print("display \(display): set \(describe(largest)), result \(result.rawValue), now \(describe(CGDisplayCopyDisplayMode(display)))")
}
