import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../keys/locker.dart';

// -----------------------------------------------------------------
// MaskedClient — HTTP client wearing a real device User-Agent.
// -----------------------------------------------------------------
// Every outbound request (gate POST, GCD retry, push image download)
// travels through this client so it carries the same UA string as
// the hosted WebView. A default Dart / Flutter UA would immediately
// identify the shell to a reviewer or affiliate scanner.
//
// The Chrome / WebKit version fragments are decoded through the
// scrambler so the version numbers never appear as literals.
// -----------------------------------------------------------------

class MaskedClient extends http.BaseClient {
  MaskedClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;
  String _ua = 'Mozilla/5.0';

  /// The current User-Agent — read by the WebView so it matches.
  String get userAgent => _ua;

  /// Reads device info and assembles the UA. Call once in main().
  Future<void> reassemble() async {
    final String chrome = _preferOr(peekChromeVer(), '149.0.7734.187');
    final String webkit = _preferOr(peekWebkitVer(), '537.36');

    try {
      final DeviceInfoPlugin probe = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo info = await probe.androidInfo;
        // Prefer the human-readable release ("14", "15") — never the
        // SDK integer, per the current TZ.
        final String release = info.version.release;
        final String buildTag =
            info.display.isNotEmpty ? info.display : info.id;
        _ua = 'Mozilla/5.0 (Linux; Android $release; '
            '${info.brand} ${info.model} Build/$buildTag) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$webkit';
      } else if (Platform.isIOS) {
        final IosDeviceInfo info = await probe.iosInfo;
        final String os = info.systemVersion.replaceAll('.', '_');
        _ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS $os like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${info.systemVersion} Mobile/15E148 Safari/$webkit';
      }
    } catch (_) {
      _ua = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UP1A.231005.007) '
          'AppleWebKit/$webkit (KHTML, like Gecko) '
          'Chrome/$chrome Mobile Safari/$webkit';
    }
  }

  static String _preferOr(String value, String fallback) =>
      value.isNotEmpty ? value : fallback;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _ua);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Shared client instance used by every relay in the shell.
final MaskedClient maskedWire = MaskedClient();
