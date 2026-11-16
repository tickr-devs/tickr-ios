import SwiftUI

extension Tokens.Typography {
  #if os(iOS)
  /// A chip's title (`ChipFace`): the boards' `.u-chip`, 13 pt bold mono (footnote, so Dynamic
  /// Type applies).
  public static let chipTitle = Font.system(.footnote, design: .monospaced, weight: .bold)
  /// A small chip's title (`ChipFace` `small`, a symbol's sources): `.u-chip.sm`, 11 pt.
  public static let chipSmallTitle = Font.system(.caption2, design: .monospaced, weight: .bold)
  /// A segment's title (`SegmentSwitch`): `.u-seg`, 12.5 pt semibold (footnote, Dynamic Type).
  public static let segment = Font.system(.footnote, weight: .semibold)
  #else
  /// A chip's title size (`ChipFace`): the boards' `.u-chip`, in points.
  public static let chipTitleSize: CGFloat = 13
  /// A small chip's title size (`ChipFace` `small`, a symbol's sources): `.u-chip.sm`, in points.
  public static let chipSmallTitleSize: CGFloat = 11
  /// A segment's title size (`SegmentSwitch`): `.u-seg`, in points.
  public static let segmentSize: CGFloat = 12.5
  /// A chip's title, 13 pt bold mono.
  public static let chipTitle = Font.system(size: chipTitleSize, weight: .bold, design: .monospaced)
  /// A small chip's title, 11 pt bold mono.
  public static let chipSmallTitle = Font.system(size: chipSmallTitleSize, weight: .bold, design: .monospaced)
  /// A segment's title, 12.5 pt semibold.
  public static let segment = Font.system(size: segmentSize, weight: .semibold)
  #endif
}
