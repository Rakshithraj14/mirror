import '../models/transaction.dart';

/// "Spent" means money leaving the account, so credits never count towards it.
double _sumDebits(Iterable<Txn> txns) => txns
    .where((t) => t.type == TxnType.debit)
    .fold(0.0, (sum, t) => sum + t.amount);

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Weeks start on Monday, matching how the calendar reads locally.
DateTime startOfWeek(DateTime d) =>
    startOfDay(d).subtract(Duration(days: d.weekday - DateTime.monday));

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

double spentSince(List<Txn> txns, DateTime from) =>
    _sumDebits(txns.where((t) => !t.time.isBefore(from)));

double spentToday(List<Txn> txns, {DateTime? now}) =>
    spentSince(txns, startOfDay(now ?? DateTime.now()));

double spentThisWeek(List<Txn> txns, {DateTime? now}) =>
    spentSince(txns, startOfWeek(now ?? DateTime.now()));

double spentThisMonth(List<Txn> txns, {DateTime? now}) =>
    spentSince(txns, startOfMonth(now ?? DateTime.now()));

/// Spend per day for the trailing [days] days, oldest first, with empty days
/// present as 0 so the line keeps a truthful time axis instead of collapsing
/// gaps together.
List<double> dailySpend(List<Txn> txns, {int days = 30, DateTime? now}) {
  final today = startOfDay(now ?? DateTime.now());
  final first = today.subtract(Duration(days: days - 1));

  final buckets = List<double>.filled(days, 0);
  for (final txn in txns) {
    if (txn.type != TxnType.debit) continue;
    final day = startOfDay(txn.time);
    if (day.isBefore(first) || day.isAfter(today)) continue;
    buckets[day.difference(first).inDays] += txn.amount;
  }
  return buckets;
}
