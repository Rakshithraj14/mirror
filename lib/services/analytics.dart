import '../models/transaction.dart';

enum Period { today, week, month }

extension PeriodX on Period {
  String get label => switch (this) {
        Period.today => 'Today',
        Period.week => 'Week',
        Period.month => 'Month',
      };

  /// What the hero number is measuring, spelled out for the reader.
  String get caption => switch (this) {
        Period.today => 'spent today',
        Period.week => 'spent this week',
        Period.month => 'spent this month',
      };

  DateTime start(DateTime now) => switch (this) {
        Period.today => startOfDay(now),
        Period.week => startOfWeek(now),
        Period.month => startOfMonth(now),
      };

  /// The far edge of the period, whether or not it has arrived yet. Charts
  /// frame the whole period so an early week reads as "just started" rather
  /// than as a squeezed, sparse plot.
  DateTime end(DateTime now) => switch (this) {
        Period.today => startOfDay(now).add(const Duration(days: 1)),
        Period.week => startOfWeek(now).add(const Duration(days: 7)),
        Period.month => DateTime(now.year, now.month + 1),
      };
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Weeks start on Monday, matching how the calendar reads locally.
DateTime startOfWeek(DateTime d) =>
    startOfDay(d).subtract(Duration(days: d.weekday - DateTime.monday));

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

/// "Spent" means money leaving the account, so credits never count towards it.
double _sumDebits(Iterable<Txn> txns) =>
    txns.where((t) => t.type == TxnType.debit).fold(0.0, (s, t) => s + t.amount);

List<Txn> inPeriod(List<Txn> txns, Period period, {DateTime? now}) {
  final from = period.start(now ?? DateTime.now());
  return txns.where((t) => !t.time.isBefore(from)).toList();
}

double spentIn(List<Txn> txns, Period period, {DateTime? now}) =>
    _sumDebits(inPeriod(txns, period, now: now));

/// Spend per category for the period, including a null key for anything still
/// untagged — the untagged total is what the dashboard nudges you to clear.
Map<String?, double> categorySpend(
  List<Txn> txns,
  Period period, {
  DateTime? now,
}) {
  final totals = <String?, double>{};
  for (final txn in inPeriod(txns, period, now: now)) {
    if (txn.type != TxnType.debit) continue;
    totals[txn.category] = (totals[txn.category] ?? 0) + txn.amount;
  }
  return totals;
}

int untaggedCount(List<Txn> txns) => txns.where((t) => !t.isTagged).length;

/// A point on the spend curve: the running total at a moment in the period.
typedef SpendPoint = ({DateTime at, double total});

/// Running total of debits through the period — one point per payment, opened
/// at the period start with zero and closed at [now].
///
/// Cumulative rather than per-day: money here moves in many small amounts on
/// scattered days, so daily totals draw a comb of spikes back to zero. A
/// running total always rises, and its steepness is the reading — how fast the
/// period is being burned through.
///
/// The curve stops at [now] and never runs to the period's end, because the
/// rest of the month has not happened yet.
List<SpendPoint> cumulativeSpend(
  List<Txn> txns,
  Period period, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final from = period.start(at);
  final debits = txns
      .where((t) =>
          t.type == TxnType.debit &&
          !t.time.isBefore(from) &&
          !t.time.isAfter(at))
      .toList()
    ..sort((a, b) => a.time.compareTo(b.time));

  final points = <SpendPoint>[(at: from, total: 0)];
  var total = 0.0;
  for (final txn in debits) {
    total += txn.amount;
    points.add((at: txn.time, total: total));
  }
  // Hold the last value out to now, so the line reaches the present rather
  // than stopping at the last payment.
  if (points.last.at.isBefore(at)) points.add((at: at, total: total));
  return points;
}

/// Change against the same span of the previous period, as a fraction.
///
/// Compares like with like: three days into a month, this weighs them against
/// the first three days of last month, not the whole of it. Comparing a
/// partial period against a complete one reads as a dramatic drop every time
/// a period rolls over.
///
/// Null when there is nothing to compare against — "+100%" against zero is
/// noise dressed up as insight.
double? changeVsPrevious(List<Txn> txns, Period period, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final from = period.start(at);
  final previousFrom = switch (period) {
    Period.today => from.subtract(const Duration(days: 1)),
    Period.week => from.subtract(const Duration(days: 7)),
    Period.month => DateTime(from.year, from.month - 1),
  };
  final previousTo = previousFrom.add(at.difference(from));

  // Inclusive of the mirrored instant, matching the current period which
  // counts everything up to and including now.
  final previous = _sumDebits(txns.where(
      (t) => !t.time.isBefore(previousFrom) && !t.time.isAfter(previousTo)));
  if (previous <= 0) return null;
  return (spentIn(txns, period, now: at) - previous) / previous;
}

/// Groups transactions by calendar day, newest day first, for a sectioned list.
Map<DateTime, List<Txn>> groupByDay(List<Txn> txns) {
  final grouped = <DateTime, List<Txn>>{};
  for (final txn in txns) {
    grouped.putIfAbsent(startOfDay(txn.time), () => []).add(txn);
  }
  return Map.fromEntries(
    grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
  );
}

/// The single heaviest spending day in the period, for the Insights tile.
({DateTime day, double amount})? highestDay(
  List<Txn> txns,
  Period period, {
  DateTime? now,
}) {
  final totals = <DateTime, double>{};
  for (final txn in inPeriod(txns, period, now: now)) {
    if (txn.type != TxnType.debit) continue;
    final day = startOfDay(txn.time);
    totals[day] = (totals[day] ?? 0) + txn.amount;
  }
  if (totals.isEmpty) return null;
  final best = totals.entries.reduce((a, b) => b.value > a.value ? b : a);
  return (day: best.key, amount: best.value);
}

/// Average spend per day over the days that have *elapsed*, not the calendar
/// length of the period. Dividing three days of spending by thirty-one would
/// report a daily average nobody is living.
double averagePerDay(List<Txn> txns, Period period, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final days = at.difference(period.start(at)).inHours / 24;
  final elapsed = days < 1 ? 1.0 : days;
  return spentIn(txns, period, now: at) / elapsed;
}

/// Money in and money out per day, for the cashflow chart.
typedef CashflowDay = ({DateTime day, double income, double expense});

List<CashflowDay> cashflowSeries(
  List<Txn> txns,
  Period period, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final from = startOfDay(period.start(at));
  final today = startOfDay(at);
  final income = <DateTime, double>{};
  final expense = <DateTime, double>{};

  for (final txn in inPeriod(txns, period, now: at)) {
    final day = startOfDay(txn.time);
    if (txn.type == TxnType.credit) {
      income[day] = (income[day] ?? 0) + txn.amount;
    } else {
      expense[day] = (expense[day] ?? 0) + txn.amount;
    }
  }

  // Every elapsed day gets a point, including the empty ones — gaps in a
  // cashflow line read as missing data rather than as a quiet day.
  final out = <CashflowDay>[];
  for (var day = from;
      !day.isAfter(today);
      day = DateTime(day.year, day.month, day.day + 1)) {
    out.add((
      day: day,
      income: income[day] ?? 0,
      expense: expense[day] ?? 0,
    ));
  }
  return out;
}

double sumIn(List<Txn> txns, Period period, TxnType type, {DateTime? now}) =>
    inPeriod(txns, period, now: now)
        .where((t) => t.type == type)
        .fold(0.0, (s, t) => s + t.amount);
