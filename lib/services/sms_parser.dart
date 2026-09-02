import '../models/transaction.dart';

// Sender IDs are the short alphanumeric codes banks send from, e.g. "VM-HDFCBK".
// Matched by substring so both "HDFCBK" and "HDFC" style IDs hit.
const _bankPrefixes = <String, String>{
  'HDFC': 'HDFC Bank',
  'SBIN': 'SBI',
  'SBI': 'SBI',
  'ICICI': 'ICICI Bank',
  'AXIS': 'Axis Bank',
  'KOTAK': 'Kotak Bank',
  'PNB': 'Punjab National Bank',
  'BOB': 'Bank of Baroda',
  'IDFC': 'IDFC First Bank',
  'YESB': 'Yes Bank',
  'CANBNK': 'Canara Bank',
  'CANARA': 'Canara Bank',
  'UNION': 'Union Bank',
  'INDUS': 'IndusInd Bank',
  'PAYTM': 'Paytm Payments Bank',
  'IPBMSG': 'India Post Payments Bank',
  'IPPB': 'India Post Payments Bank',
};

final _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false);
// Canara (and some others) abbreviate to "Dr."/"Cr.". Those count as verbs
// only when attached to an amount, so a "Dr." in a payee's name doesn't flip
// the direction of the transaction.
final _creditPattern = RegExp(
    r'credited|received'
    r'|\bcr\.?\s*(?:inr|rs\.?|₹)'
    r'|(?:inr|rs\.?|₹)\s*[\d,]+(?:\.\d{1,2})?\s*cr\b',
    caseSensitive: false);
final _debitPattern = RegExp(
    r'debited|debit|withdrawn|spent|\bsent\b|\bpaid\b'
    r'|\bdr\.?\s*(?:inr|rs\.?|₹)'
    r'|(?:inr|rs\.?|₹)\s*[\d,]+(?:\.\d{1,2})?\s*dr\b',
    caseSensitive: false);
// Requiring one of these keeps promotional "Rs 100 off" texts from matching.
final _contextPattern = RegExp(r'a/c|acct|account|upi|vpa', caseSensitive: false);
final _signaturePattern = RegExp(r'-\s*([A-Za-z][A-Za-z .]{2,30}Bank)\b');
// "…has sent money on your CANARA BANK account." A wallet app names the
// account the money actually moved in, and that is the account the balance
// belongs to — not the wallet that happened to raise the notification.
// Anchored on a following "Bank" so a payee called Bob is never read as BOB.
final _bankInBody = RegExp(
    r'\b(' + _bankPrefixes.keys.join('|') + r')\s+bank\b',
    caseSensitive: false);
// "UPI: 618239653510", "UPI Ref No 123456789012", "RRN 123456789012".
// Anchored on the keyword so a phone number or account number elsewhere in
// the message can never be mistaken for a reference — a wrong reference
// would silently discard a real transaction as a duplicate.
final _upiRefPattern = RegExp(
    r'\b(?:upi|rrn|ref(?:erence)?)\b[\s:.\-]*(?:ref(?:erence)?)?[\s:.\-]*'
    r'(?:no\.?|num(?:ber)?|id)?[\s:.\-]*(\d{10,18})',
    caseSensitive: false);

// "Bal INR 98.75", "Avl Bal: 1,343.42", "Balance Rs 500". The bank's own
// figure for the account after the transaction, which beats any running total
// we could keep ourselves.
final _balancePattern = RegExp(
    r'\bbal(?:ance)?\b\.?\s*:?\s*(?:inr|rs\.?|\u20b9)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false);

/// Payment apps whose notifications are trusted as transaction sources.
/// Anything not listed here is ignored outright — the package name is the
/// filter, which is why notification text needs no "a/c" context check.
const paymentApps = <String, String>{
  'com.samsung.android.spay': 'Samsung Wallet',
  'com.phonepe.app': 'PhonePe',
  'com.google.android.apps.nbu.paisa.user': 'Google Pay',
  'net.one97.paytm': 'Paytm',
  'in.org.npci.upiapp': 'BHIM',
  'com.canarabank.mobility': 'Canara ai1',
  'com.dreamplug.androidapp': 'CRED',
  'com.mobikwik_new': 'MobiKwik',
  'com.freecharge.android': 'Freecharge',
};

Txn? parseBankSms(String sender, String body, DateTime receivedAt) {
  // Any SMS can arrive, so an unknown sender must prove it is financial.
  if (!_contextPattern.hasMatch(body)) return null;
  return _parse(
    body: body,
    time: receivedAt,
    source: TxnSource.sms,
    rawSender: sender,
    name: _resolveBank(sender, body),
  );
}

/// Catches transactions that never produce a bank SMS — small UPI transfers
/// in particular, which several banks do not alert on.
Txn? parsePaymentNotification(
  String packageName,
  String? title,
  String? text,
  DateTime postedAt,
) {
  final app = paymentApps[packageName];
  if (app == null) return null;

  final body = [title, text].whereType<String>().join(' ').trim();
  if (body.isEmpty) return null;

  return _parse(
    body: body,
    time: postedAt,
    source: TxnSource.notification,
    rawSender: packageName,
    // Filing a Canara credit under "Samsung Wallet" invents an account that
    // does not exist and leaves the real one's balance untouched.
    name: _bankFromBody(body) ?? app,
  );
}

Txn? _parse({
  required String body,
  required DateTime time,
  required TxnSource source,
  required String rawSender,
  required String name,
}) {
  final amountMatch = _amountPattern.firstMatch(body);
  if (amountMatch == null) return null;

  // UPI debit alerts mention both sides — "debited from A/c XX1234 and
  // credited to payee@upi" — so the verb that appears first is the one
  // describing this account, not the counterparty's.
  final creditMatch = _creditPattern.firstMatch(body);
  final debitMatch = _debitPattern.firstMatch(body);
  if (creditMatch == null && debitMatch == null) return null;
  final isCredit = debitMatch == null ||
      (creditMatch != null && creditMatch.start < debitMatch.start);

  final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
  if (amount == null || amount <= 0) return null;

  // The transaction amount is read with firstMatch, so it is always the amount
  // stated before the closing balance — "Dr. INR 190.00 ... Bal INR 98.75"
  // still books 190.
  final balanceMatch = _balancePattern.firstMatch(body);
  final balance = balanceMatch == null
      ? null
      : double.tryParse(balanceMatch.group(1)!.replaceAll(',', ''));

  return Txn(
    bank: name,
    amount: amount,
    type: isCredit ? TxnType.credit : TxnType.debit,
    time: time,
    source: source,
    rawSender: rawSender,
    rawBody: body,
    upiRef: _upiRefPattern.firstMatch(body)?.group(1),
    balanceAfter: balance,
  );
}

String _resolveBank(String sender, String body) {
  final upperSender = sender.toUpperCase();
  for (final entry in _bankPrefixes.entries) {
    if (upperSender.contains(entry.key)) return entry.value;
  }
  final sig = _signaturePattern.firstMatch(body);
  if (sig != null) return sig.group(1)!.trim();
  return _bankFromBody(body) ?? 'Unknown Bank';
}

String? _bankFromBody(String body) {
  final match = _bankInBody.firstMatch(body);
  return match == null ? null : _bankPrefixes[match.group(1)!.toUpperCase()];
}
