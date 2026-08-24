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
};

final _amountPattern =
    RegExp(r'(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
final _creditPattern = RegExp(r'credited|received', caseSensitive: false);
final _debitPattern =
    RegExp(r'debited|withdrawn|spent|\bsent\b|\bpaid\b', caseSensitive: false);
// Requiring one of these keeps promotional "Rs 100 off" texts from matching.
final _contextPattern = RegExp(r'a/c|acct|account|upi|vpa', caseSensitive: false);
final _signaturePattern = RegExp(r'-\s*([A-Za-z][A-Za-z .]{2,30}Bank)\b');

Txn? parseBankSms(String sender, String body, DateTime receivedAt) {
  final amountMatch = _amountPattern.firstMatch(body);
  if (amountMatch == null) return null;
  if (!_contextPattern.hasMatch(body)) return null;

  final isCredit = _creditPattern.hasMatch(body);
  final isDebit = _debitPattern.hasMatch(body);
  if (!isCredit && !isDebit) return null;

  final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
  if (amount == null || amount <= 0) return null;

  return Txn(
    bank: _resolveBank(sender, body),
    amount: amount,
    type: isCredit ? TxnType.credit : TxnType.debit,
    time: receivedAt,
    rawSender: sender,
    rawBody: body,
  );
}

String _resolveBank(String sender, String body) {
  final upperSender = sender.toUpperCase();
  for (final entry in _bankPrefixes.entries) {
    if (upperSender.contains(entry.key)) return entry.value;
  }
  final sig = _signaturePattern.firstMatch(body);
  if (sig != null) return sig.group(1)!.trim();
  return 'Unknown Bank';
}
