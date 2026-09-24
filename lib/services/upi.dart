/// `handle@psp`, e.g. 7795356018@axl or rakshith.r@okicici. The handle is the
/// set of characters NPCI allows; the provider is letters and digits only.
final _upiId = RegExp(r'^[a-zA-Z0-9._\-]{2,256}@[a-zA-Z][a-zA-Z0-9]{1,63}$');

bool isValidUpiId(String id) => _upiId.hasMatch(id.trim());

/// The `upi://pay` link every UPI app opens when it scans a QR.
///
/// Built by hand rather than with [Uri.queryParameters], which encodes spaces
/// as `+` — several UPI apps show that literally, so "Rakshith Raj" came out
/// as "Rakshith+Raj" on the payer's screen. `pa` stays unencoded: it is already
/// validated to URL-safe characters, and some apps reject `%40` for `@`.
String upiPayUri({
  required String upiId,
  required String name,
  required double amount,
  String? note,
}) {
  final params = {
    'pa': upiId.trim(),
    'pn': Uri.encodeComponent(name.trim()),
    'am': amount.toStringAsFixed(2),
    'cu': 'INR',
    if (note != null && note.trim().isNotEmpty)
      'tn': Uri.encodeComponent(note.trim()),
  };
  return 'upi://pay?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
}
