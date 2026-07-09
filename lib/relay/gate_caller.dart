import 'dart:convert';

import '../keys/peg_config.dart';
import '../verdict/gate_verdict.dart';
import 'masked_client.dart';
import 'peg_vault.dart';

/// Posts the attribution body to the gate endpoint and returns the
/// parsed verdict. Caches the URL + expiry on a positive response so
/// subsequent launches can fall back to it if the network flaps.
///
/// A missing endpoint is treated as an immediate denial, keeping the
/// shell on the native (game) path until real credentials land.
class GateCaller {
  GateCaller(this._vault);

  final PegVault _vault;

  Future<GateVerdict> ask(Map<String, dynamic> body) async {
    final String endpoint = PegConfig.gateUrl;
    if (endpoint.isEmpty) {
      return GateVerdict.denied('no-endpoint');
    }

    try {
      final dynamic resp = await maskedWire
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        return GateVerdict.denied('http-${resp.statusCode}');
      }

      final Map<String, dynamic> raw =
          jsonDecode(resp.body) as Map<String, dynamic>;
      final GateVerdict verdict = GateVerdict.parse(raw);

      if (verdict.grantsAccess && verdict.carriesLink) {
        await _vault.storeCachedLink(verdict.link!);
        if (verdict.expiresAt != null) {
          await _vault.storeTtl(verdict.expiresAt!);
        }
      }
      return verdict;
    } catch (err) {
      return GateVerdict.denied(err.toString());
    }
  }

  Future<String?> lastKnownLink() => _vault.loadCachedLink();
}
