@testable import ApertureDesign
import CoreGraphics
import SwiftUI
import Testing

@Suite struct MarqueeTilesTests {
  /// Width of the iPhone ticker row that came out blank at @3x (2026-11-15), in points.
  static let longRow: CGFloat = 2822
  static let iPhoneScale: CGFloat = 3

  @Test func tilesCoverTheRowWithinTheLimit() {
    let spans = MarqueeTiles.spans(width: Self.longRow, scale: Self.iPhoneScale)
    #expect(spans.count > 1)
    #expect(spans.first?.x == 0)
    #expect(spans.reduce(0) { $0 + $1.width } == Self.longRow)
    for (span, next) in zip(spans, spans.dropFirst()) {
      #expect(span.x + span.width == next.x)
    }
    #expect(spans.allSatisfy { $0.width * Self.iPhoneScale <= MarqueeTiles.maxPixels })
  }

  @Test func shortRowIsOneTile() {
    let spans = MarqueeTiles.spans(width: 100, scale: 2)
    #expect(spans.count == 1)
    #expect(spans.first?.width == 100)
  }

  @Test func noWidthNoTiles() {
    #expect(MarqueeTiles.spans(width: 0, scale: Self.iPhoneScale).isEmpty)
  }

  /// A row wider than a renderer's largest texture at @3x still draws: every tile has ink.
  @MainActor @Test func longRowDrawsInk() {
    let height: CGFloat = 10
    let row = Rectangle().fill(Color.black).frame(width: Self.longRow, height: height)
    let tiles = MarqueeTiles.render(row, width: Self.longRow, scale: Self.iPhoneScale)
    #expect(tiles.count == MarqueeTiles.spans(width: Self.longRow, scale: Self.iPhoneScale).count)
    #expect(tiles.allSatisfy(Self.hasInk))
  }

  /// Whether the image's middle pixel is opaque.
  private static func hasInk(_ image: CGImage) -> Bool {
    var pixel = [UInt8](repeating: 0, count: 4)
    let drawn = pixel.withUnsafeMutableBytes { bytes -> Bool in
      guard let context = CGContext(
        data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(image, in: CGRect(
        x: -CGFloat(image.width / 2), y: -CGFloat(image.height / 2),
        width: CGFloat(image.width), height: CGFloat(image.height)))
      return true
    }
    return drawn && pixel[3] > 0
  }
}
