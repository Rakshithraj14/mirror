import '../models/account.dart';
import '../models/transaction.dart';

/// An account and what it currently holds.
typedef AccountBalance = ({
  Account account,
  double balance,
  DateTime? asOf,
  /// True when the figure came from the bank's own message rather than from
  /// adding up transactions. Shown to you, because one is trustworthy and the
  /// other quietly drifts.
  bool fromBank,
  /// True when the arithmetic went below zero on a cash account and was held
  /// at zero. Physical cash cannot be negative, so this means something is
  /// missing — an opening balance, or income never recorded.
  bool clamped,
});

/// Balance per account.
///
/// Starts from the opening figure you set and applies every transaction since.
/// That drifts the first time a payment is missed, so whenever the newest
/// transaction on an account carries the bank's own printed balance, that
/// figure wins outright and the running total is discarded.
List<AccountBalance> accountBalances(
  Iterable<Txn> txns,
  List<Account> accounts,
) {
  final byAccount = <String, List<Txn>>{};
  for (final txn in txns) {
    byAccount.putIfAbsent(txn.bank, () => []).add(txn);
  }

  final result = <AccountBalance>[];
  for (final account in accounts) {
    final rows = byAccount[account.name] ?? const <Txn>[];

    Txn? anchor;
    for (final txn in rows) {
      if (txn.balanceAfter == null) continue;
      if (anchor == null || txn.time.isAfter(anchor.time)) anchor = txn;
    }

    double balance;
    DateTime? asOf;
    if (anchor != null) {
      // Trust the bank, then apply only what happened after it spoke.
      balance = anchor.balanceAfter!;
      asOf = anchor.time;
      for (final txn in rows) {
        if (!txn.time.isAfter(anchor.time)) continue;
        balance += txn.type == TxnType.credit ? txn.amount : -txn.amount;
        if (txn.time.isAfter(asOf!)) asOf = txn.time;
      }
    } else {
      balance = account.opening;
      for (final txn in rows) {
        balance += txn.type == TxnType.credit ? txn.amount : -txn.amount;
        if (asOf == null || txn.time.isAfter(asOf)) asOf = txn.time;
      }
    }

    final clamped = account.isCash && balance < 0;
    result.add((
      account: account,
      balance: clamped ? 0 : balance,
      asOf: asOf,
      fromBank: anchor != null,
      clamped: clamped,
    ));
  }

  result.sort((a, b) => b.balance.compareTo(a.balance));
  return result;
}

double totalBalance(Iterable<AccountBalance> accounts) =>
    accounts.fold(0.0, (sum, a) => sum + a.balance);
