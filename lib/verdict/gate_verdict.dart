/// Parsed response from the gate endpoint.
///
/// Backend wire format is `{ ok, url, expires, message }`. The
/// property names are renamed here so the domain layer reads more
/// naturally; the JSON keys are still mapped verbatim inside
/// [GateVerdict.parse].
class GateVerdict {
  const GateVerdict({
    required this.grantsAccess,
    this.link,
    this.serverNote,
    this.expiresAt,
  });

  /// True iff the backend approves loading hosted content.
  final bool grantsAccess;

  /// Destination URL to display. Non-empty implies [grantsAccess].
  final String? link;

  /// Diagnostic message (e.g. "organic", "no data").
  final String? serverNote;

  /// Unix seconds after which [link] should be re-fetched.
  final int? expiresAt;

  bool get carriesLink => link != null && link!.isNotEmpty;

  factory GateVerdict.parse(Map<String, dynamic> raw) {
    return GateVerdict(
      grantsAccess: raw['ok'] as bool? ?? false,
      link: raw['url'] as String?,
      serverNote: raw['message'] as String?,
      expiresAt: raw['expires'] as int?,
    );
  }

  factory GateVerdict.denied(String note) =>
      GateVerdict(grantsAccess: false, serverNote: note);
}
