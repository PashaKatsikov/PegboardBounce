import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../verdict/route_mode.dart';

/// Persistence facade for the gray shell.
///
/// URLs live in [FlutterSecureStorage] (encrypted at rest);
/// scalar flags live in [SharedPreferences]. Keys are deliberately
/// neutral so a `dumpsys` inspection reveals nothing about intent.
class PegVault {
  PegVault({FlutterSecureStorage? locker})
      : _locker = locker ?? const FlutterSecureStorage();

  static const String _kRouteMode = 'pb.route.v2';
  static const String _kCachedLink = 'pb.cache.dst';
  static const String _kLinkTtl = 'pb.cache.ttl';
  static const String _kNotifyGate = 'pb.notify.until';
  static const String _kNotifyGranted = 'pb.notify.ok';
  static const String _kNotifyBlocked = 'pb.notify.blocked';
  static const String _kPendingUrl = 'pb.pending.dst';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _locker;

  Future<void> hydrate() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Route mode ────────────────────────────────────────────────
  RouteMode getRoute() => RouteMode.fromToken(_prefs.getString(_kRouteMode));
  Future<void> setRoute(RouteMode mode) =>
      _prefs.setString(_kRouteMode, mode.token);

  // ── Cached hosted URL (secure) ────────────────────────────────
  Future<String?> loadCachedLink() => _locker.read(key: _kCachedLink);
  Future<void> storeCachedLink(String link) =>
      _locker.write(key: _kCachedLink, value: link);

  // ── Expiry ────────────────────────────────────────────────────
  int? _readTtl() => _prefs.getInt(_kLinkTtl);
  Future<void> storeTtl(int unixSeconds) =>
      _prefs.setInt(_kLinkTtl, unixSeconds);
  bool isCachedLinkStale() {
    final int? ttl = _readTtl();
    if (ttl == null) return true;
    return _now() >= ttl;
  }

  // ── Push permission bookkeeping ───────────────────────────────
  bool isNotifyGranted() => _prefs.getBool(_kNotifyGranted) ?? false;
  Future<void> markNotifyGranted(bool v) =>
      _prefs.setBool(_kNotifyGranted, v);

  /// Set once the OS denies the dialog — Android never surfaces a
  /// second prompt, so the invite screen must stop offering it.
  bool isNotifyBlockedByOs() => _prefs.getBool(_kNotifyBlocked) ?? false;
  Future<void> markNotifyBlockedByOs() =>
      _prefs.setBool(_kNotifyBlocked, true);

  Future<void> gateNotifyPrompt(int unixSeconds) =>
      _prefs.setInt(_kNotifyGate, unixSeconds);
  int? _notifyGateUntil() => _prefs.getInt(_kNotifyGate);

  bool shouldOfferNotifyPrompt() {
    if (isNotifyGranted()) return false;
    if (isNotifyBlockedByOs()) return false;
    final int? until = _notifyGateUntil();
    if (until == null) return true;
    return _now() >= until;
  }

  // ── One-time pending push URL (secure) ────────────────────────
  Future<void> stashPendingUrl(String? url) async {
    if (url == null) {
      await _locker.delete(key: _kPendingUrl);
    } else {
      await _locker.write(key: _kPendingUrl, value: url);
    }
  }

  Future<String?> claimPendingUrl() async {
    final String? url = await _locker.read(key: _kPendingUrl);
    if (url != null) await _locker.delete(key: _kPendingUrl);
    return url;
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
