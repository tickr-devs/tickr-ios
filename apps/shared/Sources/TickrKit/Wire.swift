import Foundation

/// Wire rules of the Tickr local API, version 1 (see docs/api.md in the repository):
/// - money, prices and quantities are decimal strings ("12.34"), never JSON numbers;
/// - times are UTC strings with milliseconds ("2026-11-14T18:44:39.123Z");
/// - nullable keys are always present (with null); a missing key is a contract error.
public enum Wire {
  public static let apiVersion = 1
  public static let statusSchemaVersion = 1
  public static let commandSchemaVersion = 1
  public static let accountSchemaVersion = 1

  static let decimalPattern = "^-?[0-9]+(\\.[0-9]+)?$"
  /// A wire time: date, `timeSeparator`, clock with milliseconds, `utcSuffix`.
  static let datePart = "[0-9]{4}-[0-9]{2}-[0-9]{2}"
  static let clockPart = "[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}"
  static let timeSeparator = "T"
  static let utcSuffix = "Z"
  static let timePattern = "^" + datePart + timeSeparator + clockPart + utcSuffix + "$"
  /// The fixed locale that reads wire decimals ("." as the separator, whatever the user's locale).
  static let posixLocale = "en_US_POSIX"

  /// Joins the keys of a field's path in a contract error ("positions.0.stop").
  static let pathSeparator = "."

  /// A value that breaks a wire rule. Its cause, in the person's language, rides along as the
  /// underlying `ContractError`, so `detail(_:)` can show it.
  static func corrupted(_ codingPath: [any CodingKey], _ message: String) -> DecodingError {
    .dataCorrupted(.init(codingPath: codingPath, debugDescription: message, underlyingError: ContractError(message)))
  }

  /// Why an answer could not be read, in the person's language: the field and what is wrong
  /// with it. `String(describing:)` would show Swift's English debug form of a DecodingError.
  static func detail(_ error: Error) -> String {
    guard let error = error as? DecodingError else { return error.localizedDescription }
    switch error {
    case .keyNotFound(let key, let context):
      return String(localized: L10n.fieldMissing(path(context.codingPath + [key])))
    case .valueNotFound(_, let context):
      return String(localized: L10n.fieldNull(path(context.codingPath)))
    case .typeMismatch(_, let context):
      // A wrong type at the top has no field to name: the answer is JSON of the wrong shape.
      if context.codingPath.isEmpty { return String(localized: L10n.wrongShape) }
      return String(localized: L10n.fieldWrongType(path(context.codingPath)))
    case .dataCorrupted(let context):
      if let own = context.underlyingError as? ContractError {
        return String(localized: L10n.fieldInvalid(path(context.codingPath), own.message))
      }
      if context.codingPath.isEmpty { return String(localized: L10n.notJSON) }
      return String(localized: L10n.fieldUnknownValue(path(context.codingPath)))
    @unknown default:
      return error.localizedDescription
    }
  }

  /// "positions.0.stop": keys by name, array elements by index.
  static func path(_ keys: [any CodingKey]) -> String {
    keys.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: pathSeparator)
  }

  /// Whether all of `text` matches the anchored regular expression `pattern`.
  static func matches(_ pattern: String, _ text: String) -> Bool {
    text.range(of: pattern, options: .regularExpression) != nil
  }

  public static func decoder() -> JSONDecoder { JSONDecoder() }

  public static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }
}

/// A decimal kept exactly as written on the wire ("-1.60" stays "-1.60").
public struct DecimalString: Codable, Hashable, Sendable, CustomStringConvertible {
  public let text: String

  public init(_ text: String) throws {
    guard Wire.matches(Wire.decimalPattern, text) else {
      throw ContractError(String(localized: L10n.badDecimal(text)))
    }
    self.text = text
  }

  public var value: Decimal { Decimal(string: text, locale: Locale(identifier: Wire.posixLocale))! }
  public var description: String { text }
  public var isNegative: Bool { text.hasPrefix("-") }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    guard let text = try? container.decode(String.self) else {
      throw Wire.corrupted(container.codingPath, String(localized: L10n.expectedDecimal))
    }
    do { try self.init(text) } catch {
      throw Wire.corrupted(container.codingPath, "\(error)")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(text)
  }
}

/// A UTC time kept exactly as written on the wire, with its parsed Date for display.
public struct WireTime: Codable, Hashable, Sendable, CustomStringConvertible {
  public let text: String
  public let date: Date

  public init(_ text: String) throws {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard Wire.matches(Wire.timePattern, text), let date = formatter.date(from: text) else {
      throw ContractError(String(localized: L10n.badTime(text)))
    }
    self.text = text
    self.date = date
  }

  public var description: String { text }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    guard let text = try? container.decode(String.self) else {
      throw Wire.corrupted(container.codingPath, String(localized: L10n.expectedTime))
    }
    do { try self.init(text) } catch {
      throw Wire.corrupted(container.codingPath, "\(error)")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(text)
  }
}

public struct ContractError: Error, CustomStringConvertible, LocalizedError, Sendable {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var description: String { message }
  public var errorDescription: String? { message }
}

extension KeyedDecodingContainer {
  /// A nullable key: must be present, may be null.
  func decodeNullable<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
    guard contains(key) else {
      throw DecodingError.keyNotFound(key, .init(
        codingPath: codingPath, debugDescription: String(localized: L10n.nullableKeyMissing)))
    }
    return try decodeNil(forKey: key) ? nil : decode(T.self, forKey: key)
  }

  /// A version key that must equal `expected`.
  func decodeVersion(forKey key: Key, expected: Int) throws -> Int {
    let value = try decode(Int.self, forKey: key)
    guard value == expected else {
      throw Wire.corrupted(codingPath + [key], String(localized: L10n.unsupportedVersion(key.stringValue, value, expected)))
    }
    return value
  }
}

extension KeyedEncodingContainer {
  mutating func encodeNullable<T: Encodable>(_ value: T?, forKey key: Key) throws {
    if let value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) }
  }
}
