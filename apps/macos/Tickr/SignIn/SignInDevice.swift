import Foundation
import TickrKit
#if os(iOS)
import UIKit
#endif

/// Which device signs in: the texts that name it ("on this iPad"), tickr.bot's app client, and
/// the name the bot lists it under.
public enum SignInDevice: Sendable, Equatable {
  case mac, iPhone, iPad

  /// The name the bot lists a Mac under when the system gives it none.
  static let macName = "mac"
  /// How much of the vendor id an iPhone's or iPad's name keeps: enough to tell the owner's
  /// devices apart (signing in again under one name replaces its tokens).
  static let vendorIdLength = 8

  @MainActor
  public static var current: SignInDevice {
    #if os(macOS)
    .mac
    #else
    UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
    #endif
  }

  /// tickr.bot's app client for this device.
  public var client: AccountSignIn.Client { self == .mac ? .mac : .ios }

  /// The name the bot lists this device under.
  @MainActor
  public var botName: String {
    #if os(macOS)
    Host.current().localizedName ?? Self.macName
    #else
    let id = UIDevice.current.identifierForVendor?.uuidString.prefix(Self.vendorIdLength) ?? ""
    return "\(UIDevice.current.model) \(id)"
    #endif
  }
}
