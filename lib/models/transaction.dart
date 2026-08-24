enum TxnCategory { personal, family, office }

enum TxnType { debit, credit }

class Txn {
  final int? id;
  final String bank;
  final double amount;
  final TxnType type;
  final DateTime time;
  final String rawSender;
  final String rawBody;
  final TxnCategory? category;
  final String? reason;

  const Txn({
    this.id,
    required this.bank,
    required this.amount,
    required this.type,
    required this.time,
    required this.rawSender,
    required this.rawBody,
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
        'rawSender': rawSender,
        'rawBody': rawBody,
        'category': category?.name,
        'reason': reason,
      };

  factory Txn.fromMap(Map<String, Object?> map) => Txn(
        id: map['id'] as int?,
        bank: map['bank'] as String,
        amount: (map['amount'] as num).toDouble(),
        type: TxnType.values.byName(map['type'] as String),
        time: DateTime.fromMillisecondsSinceEpoch(map['timestampMillis'] as int),
        rawSender: map['rawSender'] as String,
        rawBody: map['rawBody'] as String,
        category: map['category'] == null
            ? null
            : TxnCategory.values.byName(map['category'] as String),
        reason: map['reason'] as String?,
      );
}
