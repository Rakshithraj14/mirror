import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/transaction.dart';
import 'package:penny/services/analytics.dart';

Txn txn(double amount, TxnType type, DateTime time, {String? category}) =>
    Txn(
      bank: 'Canara Bank',
      amount: amount,
      type: type,
      time: time,
      source: TxnSource.sms,
      rawSender: 'AD-CANBNK',
      rawBody: 'raw',
      category: category,
      reason: category == null ? null : 'reason',
    );

void main() {
  // A Wednesday, so "this week" has a Monday before it and days after it.
  final now = DateTime(2026, 9, 2, 14, 0);

  test('credits never count towards money spent', () {
    final txns = [
      txn(100, TxnType.debit, now),
      txn(5000, TxnType.credit, now),
    ];

    expect(spentIn(txns, Period.today, now: now), 100);
  });

  test('today excludes yesterday', () {
    final txns = [
      txn(100, TxnType.debit, now),
      txn(70, TxnType.debit, now.subtract(const Duration(days: 1))),
    ];

    expect(spentIn(txns, Period.today, now: now), 100);
    expect(spentIn(txns, Period.week, now: now), 170);
  });

  test('week starts on Monday, not seven days back', () {
    final monday = DateTime(2026, 8, 31, 9, 0);
    final sundayBefore = DateTime(2026, 8, 30, 9, 0);
    final txns = [
      txn(100, TxnType.debit, monday),
      txn(999, TxnType.debit, sundayBefore),
    ];

    expect(spentIn(txns, Period.week, now: now), 100,
        reason: 'the previous week must not leak in');
  });

  test('month excludes the previous month', () {
    final txns = [
      txn(100, TxnType.debit, DateTime(2026, 9, 1, 9)),
      txn(999, TxnType.debit, DateTime(2026, 8, 31, 9)),
    ];

    expect(spentIn(txns, Period.month, now: now), 100);
  });

  group('category spend', () {
    test('splits by category and keeps untagged under a null key', () {
      final txns = [
        txn(100, TxnType.debit, now, category: 'family'),
        txn(50, TxnType.debit, now, category: 'family'),
        txn(25, TxnType.debit, now),
      ];

      final totals = categorySpend(txns, Period.today, now: now);
      expect(totals['family'], 150);
      expect(totals[null], 25);
    });

    test('leaves credits out of the split', () {
      final txns = [
        txn(100, TxnType.debit, now, category: 'office'),
        txn(900, TxnType.credit, now, category: 'office'),
      ];

      expect(categorySpend(txns, Period.today, now: now)['office'],
          100);
    });
  });

  group('change vs previous period', () {
    test('is null when there is nothing to compare against', () {
      final txns = [txn(100, TxnType.debit, now)];

      expect(changeVsPrevious(txns, Period.today, now: now), isNull,
          reason: 'a jump from zero is not a meaningful percentage');
    });

    test('weighs a partial period against the same span, not the whole', () {
      // Two days into the month. Last month must count only its first two
      // days, otherwise a fresh month always reads as a collapse in spending.
      final secondOfMonth = DateTime(2026, 9, 2, 12);
      final txns = [
        txn(100, TxnType.debit, DateTime(2026, 9, 1, 10)),
        txn(100, TxnType.debit, DateTime(2026, 8, 1, 10)),
        txn(9999, TxnType.debit, DateTime(2026, 8, 20, 10)),
      ];

      expect(changeVsPrevious(txns, Period.month, now: secondOfMonth), 0,
          reason: 'the rest of last month is outside the compared span');
    });

    test('reports a rise against the previous day', () {
      final txns = [
        txn(150, TxnType.debit, now),
        txn(100, TxnType.debit, now.subtract(const Duration(days: 1))),
      ];

      expect(changeVsPrevious(txns, Period.today, now: now), closeTo(0.5, 1e-9));
    });
  });

  group('grouping', () {
    test('groups by day, newest first', () {
      final txns = [
        txn(10, TxnType.debit, now),
        txn(20, TxnType.debit, now.subtract(const Duration(days: 2))),
        txn(30, TxnType.debit, now.subtract(const Duration(hours: 2))),
      ];

      final grouped = groupByDay(txns);
      expect(grouped.keys.first, startOfDay(now));
      expect(grouped[startOfDay(now)]!.length, 2);
      expect(grouped.length, 2);
    });
  });

  test('untagged count ignores tagged rows', () {
    final txns = [
      txn(10, TxnType.debit, now, category: 'personal'),
      txn(20, TxnType.debit, now),
    ];

    expect(untaggedCount(txns), 1);
  });

  group('cumulative spend', () {
    test('opens at zero on the period start and rises with each payment', () {
      final txns = [
        txn(100, TxnType.debit, startOfWeek(now).add(const Duration(days: 1))),
        txn(50, TxnType.debit, startOfWeek(now).add(const Duration(days: 2))),
      ];

      final points = cumulativeSpend(txns, Period.week, now: now);

      expect(points.first.at, startOfWeek(now));
      expect(points.first.total, 0);
      expect(points.map((p) => p.total), [0, 100, 150, 150]);
    });

    test('never falls — credits are not spending', () {
      final txns = [
        txn(100, TxnType.debit, startOfWeek(now).add(const Duration(days: 1))),
        txn(9000, TxnType.credit,
            startOfWeek(now).add(const Duration(days: 2))),
      ];

      final totals =
          cumulativeSpend(txns, Period.week, now: now).map((p) => p.total);

      expect(totals.last, 100);
      expect(totals.toList(), orderedEquals([0, 100, 100]));
    });

    test('stops at now, not at the end of the period', () {
      // Framing the line out to Sunday would draw four flat days that have not
      // happened yet, reading as "spent nothing" rather than "not yet".
      final txns = [
        txn(100, TxnType.debit, startOfWeek(now).add(const Duration(days: 1))),
      ];

      expect(cumulativeSpend(txns, Period.week, now: now).last.at, now);
    });

    test('ignores payments from outside the period', () {
      final txns = [
        txn(999, TxnType.debit,
            startOfWeek(now).subtract(const Duration(days: 1))),
        txn(100, TxnType.debit, startOfWeek(now).add(const Duration(days: 1))),
      ];

      expect(cumulativeSpend(txns, Period.week, now: now).last.total, 100);
    });

    test('an empty period is a single point, not a line', () {
      expect(cumulativeSpend([], Period.month, now: now).length, 2);
      expect(cumulativeSpend([], Period.month, now: now).last.total, 0);
    });
  });
}
