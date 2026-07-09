import 'dart:typed_data';

// -----------------------------------------------------------------
// Scrambler — reversible byte hider for the Pegboard Bounce shell.
// -----------------------------------------------------------------
// Sensitive constants (gate endpoint, attribution key, messaging id,
// UA version fragments) travel as byte lists. Plaintext MUST NOT
// appear as a literal in any file that feeds this decoder.
//
// Algorithm (project-unique — do not port to any other app):
//   1. Seed phrase feeds a Jenkins one-at-a-time hash (32 bits).
//   2. Two independent LCGs seeded from that hash generate a
//      keystream of [_padSize] bytes.
//   3. Each byte encodes as: input ^ pad[i % len] ^ ((i * 37) & 0xFF).
//
// The multiplication by 37 on the offset makes the positional XOR
// diverge from any project that used a simpler (i & 0xFF) scheme.
// -----------------------------------------------------------------

// Per-project random ASCII phrase. No dictionary words tied to
// the game theme — must not be greppable to "pegboard" or similar.
const String _seedPhrase = 'Bn7q!wV3zk_pXm2';

// Keystream length — chosen odd + not a divisor of common English
// word lengths so short/long strings both benefit from mixing.
const int _padSize = 37;

Uint8List _mixPad() {
  int h = 0;
  for (final int c in _seedPhrase.codeUnits) {
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

  final Uint8List pad = Uint8List(_padSize);
  for (int i = 0; i < _padSize; i++) {
    a = (a * 1103515245 + 12345) & 0xFFFFFFFF;
    b = (b * 1664525 + 1013904223) & 0xFFFFFFFF;
    pad[i] = ((a >> 8) ^ (b >> 16)) & 0xFF;
  }
  return pad;
}

final Uint8List _pad = _mixPad();

/// Decodes an encoded byte list back into the original string. An
/// empty list decodes to "" — used as a safe default until real
/// credentials are packed via tool/pack_secrets.dart.
String unscramble(List<int> packed) {
  if (packed.isEmpty) return '';
  final Uint8List out = Uint8List(packed.length);
  for (int i = 0; i < packed.length; i++) {
    out[i] = (packed[i] ^ _pad[i % _padSize] ^ ((i * 37) & 0xFF)) & 0xFF;
  }
  return String.fromCharCodes(out);
}
