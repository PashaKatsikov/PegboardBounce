import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../keys/locker.dart';
import '../keys/peg_config.dart';
import 'masked_client.dart';

// -----------------------------------------------------------------
// SourceTracker — AppsFlyer attribution collector.
// -----------------------------------------------------------------
// Collects the install-conversion payload, deep-link click event
// and app-open attribution, then merges them into the gate body.
//
// Organic false-positive guard: AppsFlyer sometimes returns
// af_status == "Organic" on the first callback for genuinely paid
// installs. When that happens we wait a few seconds and re-query
// the GCD endpoint to obtain the real attribution.
// -----------------------------------------------------------------

class SourceTracker {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _conversion;
  Map<String, dynamic>? _deepLink;
  Map<String, dynamic>? _appOpen;

  final Completer<Map<String, dynamic>> _conversionReady =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkReady = Completer<void>();

  bool _launched = false;

  Future<void> launch() async {
    if (_launched) return;
    _launched = true;

    final String devKey = PegConfig.attributionKey;
    if (devKey.isEmpty) {
      // No dev key yet — release the awaits immediately so the flow
      // does not stall for 30s.
      _releaseConversion(<String, dynamic>{});
      _releaseDeepLink();
      return;
    }

    final AppsFlyerOptions opts = AppsFlyerOptions(
      afDevKey: devKey,
      appId: PegConfig.iosAppId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );
    final AppsflyerSdk sdk = AppsflyerSdk(opts);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic raw) async {
      final Map<String, dynamic> payload = _flatten(raw);
      final String? status = payload['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: PegConfig.organicRecheckSeconds),
        );
        final Map<String, dynamic>? recheck = await _refreshViaGcd();
        _conversion = recheck ?? payload;
      } else {
        _conversion = payload;
      }
      _releaseConversion(_conversion ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic raw) {
      _appOpen = _flatten(raw);
    });

    sdk.onDeepLinking((DeepLinkResult r) {
      final Map<String, dynamic>? click = r.deepLink?.clickEvent;
      if (click != null) {
        _deepLink = Map<String, dynamic>.from(click);
      }
      _releaseDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _releaseConversion(<String, dynamic>{});
      _releaseDeepLink();
    }
  }

  /// Blocks (with a ceiling) until the install-conversion payload arrives.
  Future<Map<String, dynamic>> awaitConversion({int seconds = 30}) {
    return _conversionReady.future.timeout(
      Duration(seconds: seconds),
      onTimeout: () => <String, dynamic>{},
    );
  }

  Future<void> awaitDeepLink() {
    return _deepLinkReady.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  Future<String?> installUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Merges every source into the flat body expected by the gate.
  /// Conversion writes wins the first pass, deep-link + app-open
  /// fill blanks via `putIfAbsent`, device fields overwrite at the end.
  Future<Map<String, dynamic>> assembleBody({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (_conversion != null) body.addAll(_conversion!);
    _deepLink?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpen?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await installUid() ?? '';
    body['bundle_id'] = PegConfig.bundleName;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = PegConfig.storefrontId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = PegConfig.messagingProjectId;
    if (project.isNotEmpty) {
      body['firebase_project_id'] = project;
    }

    if (kDebugMode) {
      debugPrint('[SourceTracker] body: ${jsonEncode(body)}');
    }
    return body;
  }

  Future<Map<String, dynamic>?> _refreshViaGcd() async {
    try {
      final String? uid = await installUid();
      if (uid == null) return null;
      final String appId =
          Platform.isIOS ? PegConfig.iosAppId : PegConfig.bundleName;
      final String url = peekGcdUrl(appId, uid);
      if (url.isEmpty) return null;

      final dynamic resp = await maskedWire.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${PegConfig.attributionKey}',
        },
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _releaseConversion(Map<String, dynamic> data) {
    if (!_conversionReady.isCompleted) _conversionReady.complete(data);
  }

  void _releaseDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  static Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final dynamic core = raw['payload'] ?? raw['data'] ?? raw;
    if (core is Map) {
      return core.map((dynamic k, dynamic v) =>
          MapEntry<String, dynamic>(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
