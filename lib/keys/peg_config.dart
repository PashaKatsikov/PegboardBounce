import 'locker.dart';
import 'public_urls.dart';

/// Central bag of app-wide constants used across the gray shell.
///
/// Identity fields are plaintext (they must match the store listing);
/// endpoints and credentials resolve lazily through [Locker] so raw
/// strings never land in the compiled binary.
class PegConfig {
  PegConfig._();

  static const String bundleName = 'com.pegbounce.pegboardbounce';
  static const String storefrontId = 'com.pegbounce.pegboardbounce';
  static const String displayLabel = 'Pegboard Bounce';

  /// iOS numeric App Store id — kept empty on Android-only builds so
  /// the attribution SDK can still be initialised without an appId.
  static const String iosAppId = '';

  // ── Resolved endpoints / credentials ──────────────────────────
  static String get gateUrl => peekGateUrl();
  static String get attributionKey => peekAfDevKey();
  static String get messagingProjectId => peekFbProject();

  // ── Public legal / marketing links ────────────────────────────
  static const String privacyUrl = kPrivacyPolicy;
  static const String supportUrl = kSupportPage;
  static const String siteHome = kSiteHome;

  // ── Timing ────────────────────────────────────────────────────
  /// Cooldown before the push-invite screen may reappear after a
  /// Skip / permission denial (3 days, per TZ).
  static const int notifyPromptCooldown = 3 * 24 * 60 * 60;

  /// Delay between the initial AppsFlyer conversion callback and
  /// the GCD recheck when the SDK first reports Organic.
  static const int organicRecheckSeconds = 5;
}
