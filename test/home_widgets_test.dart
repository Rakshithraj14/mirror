import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/transaction.dart';
import 'package:penny/services/home_widgets.dart';

Txn _txn(double amount, DateTime time,
        {TxnType type = TxnType.debit, String? category = 'personal'}) =>
    Txn(
      bank: 'Canara Bank',
      amount: amount,
      type: type,
      time: time,
      source: TxnSource.sms,
      rawSender: 'AD-CANBNK',
      rawBody: '',
      category: category,
    );

void main() {
  final now = DateTime(2026, 9, 30, 18, 30);

  test('today counts debits since midnight only', () {
    final s = todaySnapshot([
      _txn(120, DateTime(2026, 9, 30, 9)),
      _txn(300, DateTime(2026, 9, 30, 13)),
      _txn(5000, DateTime(2026, 9, 30, 10), type: TxnType.credit),
      _txn(999, DateTime(2026, 9, 29, 23, 59)),
    ], now);
    expect(s.day, '2026-09-30');
    expect(s.spent, '₹420');
  });

  test('average is over the days before today, back to the first payment',
      () {
    // Three full days of history: 600 over 3 days, today excluded.
    final s = todaySnapshot([
      _txn(100, DateTime(2026, 9, 27, 12)),
      _txn(500, DateTime(2026, 9, 29, 12)),
      _txn(10000, DateTime(2026, 9, 30, 12)),
    ], now);
    expect(s.average, 'avg ₹200/day');
  });

  test('average looks back 30 days at most', () {
    final s = todaySnapshot([
      _txn(99999, DateTime(2026, 6, 1)), // long ago, outside the window
      _txn(3000, DateTime(2026, 9, 15)),
    ], now);
    expect(s.average, 'avg ₹100/day');
  });

  test('a first-day install has no average to compare against', () {
    final s = todaySnapshot([_txn(50, DateTime(2026, 9, 30, 8))], now);
    expect(s.average, isEmpty);
    expect(todaySnapshot(const [], now).spent, '₹0');
  });

  test('untagged is counted, and silent when there are none', () {
    final s = todaySnapshot([
      _txn(10, DateTime(2026, 9, 30, 8), category: null),
      _txn(20, DateTime(2026, 9, 28, 8), category: null),
      _txn(30, DateTime(2026, 9, 30, 9)),
    ], now);
    expect(s.untagged, '2 untagged');
    expect(todaySnapshot([_txn(30, DateTime(2026, 9, 30, 9))], now).untagged,
        isEmpty);
  });

  test('amounts use Indian digit grouping', () {
    final s = todaySnapshot([_txn(123456, DateTime(2026, 9, 30, 9))], now);
    expect(s.spent, '₹1,23,456');
  });
}
