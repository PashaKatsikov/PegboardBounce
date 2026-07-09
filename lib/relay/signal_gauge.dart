import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity sensor tuned for the gray shell.
///
/// [isReachable] does a real DNS lookup on top of the adapter check so
/// captive portals and VPN-limited networks are treated as offline.
/// VPN adapters count as valid connectivity (per gray-part pitfalls
/// §3 — a tethered VPN can otherwise flap the No-Wi-Fi screen).
class SignalGauge {
  SignalGauge({Connectivity? plugin})
      : _plugin = plugin ?? Connectivity();

  final Connectivity _plugin;

  static const Set<ConnectivityResult> _liveAdapters = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  /// Rotating DNS probe hosts — reduces the chance that a single
  /// ISP-blocked domain reads as "offline".
  static const List<String> _probeHosts = <String>[
    'cloudflare.com',
    'apple.com',
    'wikipedia.org',
  ];

  Future<bool> isReachable() async {
    final List<ConnectivityResult> states =
        await _plugin.checkConnectivity();
    final bool hasLive = states.any(_liveAdapters.contains);
    if (!hasLive) return false;

    for (final String host in _probeHosts) {
      try {
        final List<InternetAddress> hit = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 7));
        if (hit.isNotEmpty && hit.first.rawAddress.isNotEmpty) return true;
      } catch (_) {
        // Try the next probe host on any DNS failure.
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get pulses =>
      _plugin.onConnectivityChanged;
}
