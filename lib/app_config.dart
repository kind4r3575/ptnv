/// App-wide constants for external destinations (GitHub, store listings).
///
/// Kept separate from `theme/tokens.dart` since these are identity/config
/// values, not design tokens.
class AppConfig {
  AppConfig._();

  /// Flip to `true` once Pod Tracker has a live Play Store / App Store
  /// listing. Until then, "Rate the App" shows a friendly "coming soon"
  /// message instead of opening a store page that doesn't exist yet.
  static const bool isPublished = false;

  /// Numeric App Store id — the digits in `apps.apple.com/app/id######`.
  /// Only needed for the iOS "Rate the App" link; fill in once the app has
  /// been submitted to App Store Connect. The Android path needs no such
  /// constant since the Play Store is addressed by package name, read at
  /// runtime via `package_info_plus`.
  static const String? appStoreId = null;

  static const String githubRepoUrl = 'https://github.com/kind4r3575/ptnv';
  static const String githubIssuesUrl = '$githubRepoUrl/issues';
}
