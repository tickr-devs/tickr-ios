import Foundation

/// Where a target's String Catalog is read from.
///
/// Foundation picks a resource bundle's language from the main bundle's languages: in the apps
/// that is the person's language, but in a process whose main bundle lists none (`swift test`'s
/// runner, `swift run`) every package bundle stays English, even when the process was given a
/// language at launch (`-AppleLanguages (ru)`). A language given that way (the argument domain)
/// is honoured here by reading its folder (`ru.lproj`) directly; without one Foundation decides,
/// as before.
public enum StringsBundle {
  /// Foundation's preference key of the process's languages.
  static let languagesKey = "AppleLanguages"
  /// Extension of a bundle's per-language folder.
  static let languageFolder = "lproj"

  /// The `bundle:` of every `LocalizedStringResource` read from `bundle`'s String Catalog.
  public static func description(of bundle: Bundle) -> LocalizedStringResource.BundleDescription {
    .atURL(url(of: bundle))
  }

  /// The folder of `bundle`'s strings in the language the process was given at launch, or the
  /// bundle itself when it was given none (or the bundle has no folder for it).
  static func url(of bundle: Bundle) -> URL {
    let given = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)[languagesKey]
    guard let languages = given as? [String],
      let language = Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: languages).first,
      let folder = bundle.url(forResource: language, withExtension: languageFolder) else {
      return bundle.bundleURL
    }
    return folder
  }
}
