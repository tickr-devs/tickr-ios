// Screen capture for the macOS screen tour (apps/macos/TickrUITests/ScreenTourUITests.swift).
//
// macOS grants screen recording per app, and a UI test runner is a new app on every build, so
// XCUIScreen screenshots would need a new permission each time. Instead this script, started from
// a terminal (or Claude) that already has the Screen Recording permission, takes the pictures:
// the tour drops `<name>.request` files into a folder and waits; this writes `<name>.png` of the
// app's window and then `<name>.done`.
//
// Usage: swift apps/scripts/tour_capture.swift <folder> [bundle id, default bot.tickr.mac]
// The app is found by bundle id, not by name: its display name (Tickr) is not its process name.
// The sandboxed test runner can only write inside its container, so <folder> is
// ~/Library/Containers/bot.tickr.mac.uitests.xctrunner/Data/tmp/<TOUR_CAPTURE name>.
// Stops when `<folder>/stop` appears (the tour writes it when it ends).

import AppKit
import CoreGraphics
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
  FileHandle.standardError.write(Data("usage: tour_capture.swift <folder> [bundle id]\n".utf8))
  exit(2)
}
let folder = URL(fileURLWithPath: arguments[1], isDirectory: true)
let bundleID = arguments.count >= 3 ? arguments[2] : "bot.tickr.mac"
let poll: UInt32 = 200_000  // microseconds between looks at the folder
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
// A folder reused from an earlier run: its stop, answers and pictures would end this run at once
// or pass old pictures off as new ones.
let leftovers = [".request", ".done", ".failed", ".png"]
for file in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
where file == "stop" || leftovers.contains(where: file.hasSuffix) {
  try FileManager.default.removeItem(at: folder.appendingPathComponent(file))
}

/// On-screen normal windows of the app (every running process with its bundle id), front to back.
func windows() -> [[String: Any]] {
  let pids = Set(NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    .map { Int($0.processIdentifier) })
  let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []
  return all.filter {
    pids.contains($0[kCGWindowOwnerPID as String] as? Int ?? -1) && ($0[kCGWindowLayer as String] as? Int) == 0
  }
}

func bounds(_ window: [String: Any]) -> CGRect? {
  guard let raw = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
  return CGRect(dictionaryRepresentation: raw as CFDictionary)
}

/// `main`: the app's largest window, with any sheet or menu on top of it (a screen region);
/// `front`: its frontmost window (Settings).
func capture(_ name: String, kind: String) -> Bool {
  let list = windows()
  let chosen = kind == "front" ? list.first : list.max {
    (bounds($0)?.width ?? 0) * (bounds($0)?.height ?? 0) < (bounds($1)?.width ?? 0) * (bounds($1)?.height ?? 0)
  }
  guard let window = chosen, let rect = bounds(window) else { return false }
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
  let region = "\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height))"
  task.arguments = ["-x", "-R", region, folder.appendingPathComponent("\(name).png").path]
  do { try task.run() } catch { return false }
  task.waitUntilExit()
  return task.terminationStatus == 0
}

print("tour_capture: watching \(folder.path) for \(bundleID)")
while !FileManager.default.fileExists(atPath: folder.appendingPathComponent("stop").path) {
  let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
  for file in names where file.hasSuffix(".request") {
    let name = String(file.dropLast(".request".count))
    let request = folder.appendingPathComponent(file)
    let kind = (try? String(contentsOf: request, encoding: .utf8))?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? "main"
    let ok = capture(name, kind: kind)
    try? FileManager.default.removeItem(at: request)
    let result = folder.appendingPathComponent("\(name).\(ok ? "done" : "failed")")
    FileManager.default.createFile(atPath: result.path, contents: nil)
    print("tour_capture: \(name) \(ok ? "captured" : "FAILED")")
  }
  usleep(poll)
}
print("tour_capture: stopped")
