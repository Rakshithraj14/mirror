/// Where money sits. Banks arrive on their own the first time they send a
/// message; cash and anything else you add by hand.
enum AccountKind { bank, cash }

class Account {
  final String name;
  final AccountKind kind;

  /// What the account held before Yumeko started watching. Everything after
  /// is worked out from the transactions.
  final double opening;
  final int position;

  const Account({
    required this.name,
    required this.kind,
    this.opening = 0,
    this.position = 0,
  });

  bool get isCash => kind == AccountKind.cash;

  Map<String, Object?> toMap() => {
        'name': name,
        'kind': kind.name,
        'opening': opening,
        'position': position,
      };

  factory Account.fromMap(Map<String, Object?> map) => Account(
        name: map['name'] as String,
        kind: AccountKind.values.byName(map['kind'] as String? ?? 'bank'),
        opening: (map['opening'] as num?)?.toDouble() ?? 0,
        position: (map['position'] as int?) ?? 0,
      );

  Account copyWith({String? name, AccountKind? kind, double? opening}) =>
      Account(
        name: name ?? this.name,
        kind: kind ?? this.kind,
        opening: opening ?? this.opening,
        position: position,
      );
}

/// Manual entries are recorded against this by default.
const cashAccount = 'Cash';
