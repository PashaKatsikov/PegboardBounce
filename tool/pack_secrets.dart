// ignore_for_file: avoid_print
// ---------------------------------------------------------------
// pack_secrets.dart
// ---------------------------------------------------------------
// Encodes plaintext secrets into the byte arrays consumed by
// `lib/keys/locker.dart`. Mirrors the algorithm in
// `lib/keys/scrambler.dart` exactly.
//
// Run via:
//     dart run tool/pack_secrets.dart
//
// Then paste the printed arrays into `lib/keys/locker.dart`.
//
// Never port this script to PowerShell — Dart uses native 64-bit
// integers; PowerShell overflows at 32 bits and corrupts bytes.
// ---------------------------------------------------------------

// Keep IDENTICAL to `lib/keys/scrambler.dart`.
const String seedPhrase = 'Bn7q!wV3zk_pXm2';
const int padSize = 37;

List<int> _mixPad() {
  int h = 0;
  for (final int c in seedPhrase.codeUnits) {
    h = (h + c) & 0xFFFFFFFF;
    h = (h + ((h << 10) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    h ^= (h >> 6);
  }
  h = (h + ((h << 3) & 0xFFFFFFFF)) & 0xFFFFFFFF;
  h ^= (h >> 11);
  h = (h + ((h << 15) & 0xFFFFFFFF)) & 0xFFFFFFFF;
  if (h == 0) h = 0xDEADBEEF;

  int a = h == 0 ? 1 : h;
  int b = ((h * 0x9E3779B1) ^ 0x5A827999) & 0xFFFFFFFF;
  if (b == 0) b = 0x243F6A88;

  final List<int> pad = List<int>.filled(padSize, 0);
  for (int i = 0; i < padSize; i++) {
    a = (a * 1103515245 + 12345) & 0xFFFFFFFF;
    b = (b * 1664525 + 1013904223) & 0xFFFFFFFF;
    pad[i] = ((a >> 8) ^ (b >> 16)) & 0xFF;
  }
  return pad;
}

final List<int> pad = _mixPad();

List<int> pack(String value) {
  final List<int> bytes = value.codeUnits;
  final List<int> out = List<int>.filled(bytes.length, 0);
  for (int i = 0; i < bytes.length; i++) {
    out[i] = (bytes[i] ^ pad[i % padSize] ^ ((i * 37) & 0xFF)) & 0xFF;
  }
  return out;
}

void emit(String label, String plain) {
  if (plain.isEmpty) {
    print('// $label — (empty, fill in later)');
    print('const <int>[];\n');
    return;
  }
  final List<int> packed = pack(plain);
  print('// $label  <= "$plain"');
  print('const <int>[${packed.join(', ')}],\n');
}

void main() {
  const String gateUrl = 'https://pegboardbounce.com/config.php';
  const String gcdBase = 'https://gcdsdk.appsflyer.com/install_data/v4.0/';

  // Chrome 149 — unique build/patch for this project.
  const String chromeVersion = '149.0.7734.187';
  const String webkitVersion = '537.36';

  const String afDevKey = 'jSzFRejpWQC3MZaHqG4uBa';
  const String fbProject = '163338921151';

  print('=== Pegboard Bounce · pack_secrets ===\n');
  emit('gateUrl', gateUrl);
  emit('gcdBase', gcdBase);
  emit('chromeVersion', chromeVersion);
  emit('webkitVersion', webkitVersion);
  emit('afDevKey', afDevKey);
  emit('fbProject', fbProject);
}
