import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/transaction.dart';
import 'package:penny/services/analytics.dart';

Txn txn(double amount, TxnType type, DateTime time) => Txn(
      bank: 'Canara Bank',
      amount: amount,
      type: type,
      time: time,
      source: TxnSource.sms,
      rawSender: 'AD-CANBNK',
      rawBody: 'raw',
    );

void main() {
  // A Wednesday, so "this week" has a Monday before it and days after it.
  final now = DateTime(2026, 9, 2, 14, 0);

  test('credits never count towards money spent', () {
    final txns = [
      txn(100, TxnType.debit, now),
      txn(5000, TxnType.credit, now),
    ];

    expect(spentToday(txns, now: now), 100);
  });

  test('today excludes yesterday', () {
    final txns = [
      txn(100, TxnType.debit, now),
      txn(70, TxnType.debit, now.subtract(const Duration(days: 1))),
    ];

    expect(spentToday(txns, now: now), 100);
    expect(spentThisWeek(txns, now: now), 170);
  });

  test('week starts on Monday, not seven days back', () {
    final monday = DateTime(2026, 8, 31, 9, 0);
    final sundayBefore = DateTime(2026, 8, 30, 9, 0);
    final txns = [
      txn(100, TxnType.debit, monday),
      txn(999, TxnType.debit, sundayBefore),
    ];

    expect(spentThisWeek(txns, now: now), 100,
        reason: 'the previous week must not leak in');
  });

  test('month excludes the previous month', () {
    final txns = [
      txn(100, TxnType.debit, DateTime(2026, 9, 1, 9)),
      txn(999, TxnType.debit, DateTime(2026, 8, 31, 9)),
    ];

    expect(spentThisMonth(txns, now: now), 100);
  });

  group('daily series', () {
    test('keeps empty days as zero so the time axis stays honest', () {
      final series = dailySpend(
        [txn(50, TxnType.debit, now.subtract(const Duration(days: 2)))],
        days: 5,
        now: now,
      );

      expect(series.length, 5);
      expect(series, [0, 0, 50, 0, 0]);
    });

    test('sums several transactions on the same day', () {
      final series = dailySpend(
        [
          txn(30, TxnType.debit, now),
          txn(20, TxnType.debit, now.subtract(const Duration(hours: 3))),
        ],
        days: 3,
        now: now,
      );

      expect(series.last, 50);
    });

    test('drops transactions older than the window', () {
      final series = dailySpend(
        [txn(500, TxnType.debit, now.subtract(const Duration(days: 40)))],
        days: 30,
        now: now,
      );

      expect(series.every((v) => v == 0), isTrue);
    });
  });
}
