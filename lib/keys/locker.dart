import 'scrambler.dart';

// -----------------------------------------------------------------
// Locker — encoded byte arrays for network-facing constants.
// -----------------------------------------------------------------
// Every value is a scrambler-encoded byte list. Real values will be
// dropped in later via tool/pack_secrets.dart once the AppsFlyer
// dev key and the Firebase project number arrive.
//
// While these arrays remain empty the app degrades gracefully:
// gate lookups short-circuit to a "denied" reply and the shell
// stays on the native (game) side.
// -----------------------------------------------------------------

const List<int> _gateUrl = <int>[216, 122, 92, 173, 182, 108, 44, 196, 13, 249, 215, 216, 225, 92, 26, 160, 10, 197, 195, 188, 249, 227, 117, 164, 176, 31, 118, 117, 43, 178, 74, 197, 29, 67, 7, 253, 141];

const List<int> _gcdBase = <int>[216, 122, 92, 173, 182, 108, 44, 196, 26, 255, 212, 201, 234, 86, 70, 165, 24, 218, 197, 180, 246, 255, 62, 181, 241, 17, 54, 123, 107, 181, 66, 223, 14, 12, 27, 249, 162, 141, 52, 181, 27, 147, 139, 222, 154, 228, 88];

const List<int> _chromeVer = <int>[129, 58, 17, 243, 245, 120, 52, 220, 78, 168, 158, 139, 182, 10];

const List<int> _webkitVer = <int>[133, 61, 31, 243, 246, 96];

const List<int> _afDevKey = <int>[218, 93, 82, 155, 151, 51, 105, 155, 42, 205, 243, 137, 195, 103, 9, 140, 25, 237, 130, 167, 216, 231];

const List<int> _fbProject = <int>[129, 56, 27, 238, 246, 110, 58, 217, 76, 173, 133, 139];

String peekGateUrl() => unscramble(_gateUrl);
String peekAfDevKey() => unscramble(_afDevKey);
String peekFbProject() => unscramble(_fbProject);
String peekChromeVer() => unscramble(_chromeVer);
String peekWebkitVer() => unscramble(_webkitVer);

/// Builds the GCD retry URL. Returns "" if the base URL is empty
/// (i.e. attribution retry is currently unavailable).
String peekGcdUrl(String appId, String deviceId) {
  final String base = unscramble(_gcdBase);
  if (base.isEmpty) return '';
  return '$base$appId?devkey=${peekAfDevKey()}&device_id=$deviceId';
}
