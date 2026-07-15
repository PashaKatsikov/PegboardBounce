import 'package:clarity_flutter/clarity_flutter.dart';

import '../keys/clarity_env.dart';

/// Crash-safe facade over Microsoft Clarity.
///
/// Session replay captures the native Flutter surface (loading, push-invite,
/// offline and the WebView container). Custom events + tags answer the four
/// funnel questions: drop-off screen, offer reachability, auth/deposit path,
/// and notification permission outcome.
///
/// Every public call is guarded so a Clarity failure can NEVER crash the
/// gray flow.
class Insight {
  const Insight._();

  static ClarityConfig get config => ClarityConfig(
        projectId: kClarityProjectId,
        logLevel: LogLevel.None,
      );

  /// Group the session by AppsFlyer install id + attach attribution tags.
  /// No-op when [aid] is blank so a missing af_id never wipes a good user id.
  static void identify(String? aid, {Map<String, String> tags = const {}}) {
    if (aid != null && aid.isNotEmpty) {
      _guard(() => Clarity.setCustomUserId(_clip(aid, 255)));
      tag('aid', aid);
    }
    tags.forEach(tag);
  }

  /// Set the current screen name AND emit a stable `screen_<name>` event.
  /// The `last_screen` tag is updated on every call so the dashboard can
  /// filter sessions by the exact screen the user dropped off on.
  static void screen(String name) {
    screenName(name);
    event('screen_$name');
  }

  /// Update the current screen label + mirror it to the persistent
  /// `last_screen` tag (Clarity keeps the LAST value per session).
  static void screenName(String name) => _guard(() {
        Clarity.setCurrentScreenName(_clip(name, 255));
        Clarity.setCustomTag('last_screen', _clip(name, 255));
      });

  static void event(String name) =>
      _guard(() => Clarity.sendCustomEvent(_clip(name, 254)));

  static void tag(String key, String value) {
    if (value.isEmpty) return;
    _guard(() => Clarity.setCustomTag(key, _clip(value, 255)));
  }

  // ── internals ─────────────────────────────────────────────────

  static String _clip(String v, int max) =>
      v.length <= max ? v : v.substring(0, max);

  static void _guard(void Function() body) {
    try {
      body();
    } catch (_) {}
  }
}
