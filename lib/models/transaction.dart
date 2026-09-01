enum TxnType { debit, credit }

/// `source` is stored as the enum's name, so adding a value never needs a
/// migration — old rows simply never say `manual`.
enum TxnSource { sms, notification, manual }

class Txn {
  final int? id;
  final String bank;
  final double amount;
  final TxnType type;
  final DateTime time;
  final TxnSource source;
  final String rawSender;
  final String rawBody;

  /// UPI retrieval reference number, when the message exposes one. The
  /// strongest de-duplication key available: it identifies the transaction
  /// itself rather than a coincidence of amount and timing.
  final String? upiRef;
  /// The account balance the bank printed in the same message, when it did.
  /// Treated as ground truth: it is the bank's own figure, not our arithmetic.
  final double? balanceAfter;
  /// The id of a row in `categories`, or null while still untagged.
  final String? category;
  final String? reason;

  const Txn({
    this.id,
    required this.bank,
    required this.amount,
    required this.type,
    required this.time,
    required this.source,
    required this.rawSender,
    required this.rawBody,
    this.upiRef,
    this.balanceAfter,
    this.category,
    this.reason,
  });

  bool get isTagged => category != null;

  Map<String, Object?> toMap() => {
        'id': id,
        'bank': bank,
        'amount': amount,
        'type': type.name,
        'timestampMillis': time.millisecondsSinceEpoch,
        'source': source.name,
        'rawSender': rawSender,
        'rawBody': rawBody,
        'upiRef': upiRef,
        'balanceAfter': balanceAfter,
        'category': category,
        'reason': reason,
      };

  factory Txn.fromMap(Map<String, Object?> map) => Txn(
        id: map['id'] as int?,
        bank: map['bank'] as String,
        amount: (map['amount'] as num).toDouble(),
        type: TxnType.values.byName(map['type'] as String),
        time: DateTime.fromMillisecondsSinceEpoch(map['timestampMillis'] as int),
        source: TxnSource.values.byName(map['source'] as String? ?? 'sms'),
        rawSender: map['rawSender'] as String,
        rawBody: map['rawBody'] as String,
        upiRef: map['upiRef'] as String?,
        balanceAfter: (map['balanceAfter'] as num?)?.toDouble(),
        category: map['category'] as String?,
        reason: map['reason'] as String?,
      );
}
