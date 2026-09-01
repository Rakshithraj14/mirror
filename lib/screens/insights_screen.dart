import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/analytics.dart';
import '../services/tags.dart';
import '../theme.dart';
import '../widgets/donut_chart.dart';
import '../widgets/spend_curve.dart';
import 'overview_screen.dart';

/// Where the money went, in four readings of the same period.
class InsightsScreen extends StatefulWidget {
  final List<Txn> txns;
  final DateTime now;

  const InsightsScreen({
    super.key,
    required this.txns,
    required this.now,
  });

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  Period _period = Period.month;
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Only the top few tags get their own slice; the rest collapse into
  /// "Others" rather than generating ramp steps nobody can tell apart.
  static const _maxSlices = 4;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final txns = widget.txns;
    final now = widget.now;

    final spent = spentIn(txns, _period, now: now);
    final change = changeVsPrevious(txns, _period, now: now);
    final peak = highestDay(txns, _period, now: now);
    final perDay = averagePerDay(txns, _period, now: now);
    final count = inPeriod(txns, _period, now: now).length;

    final tags = tagSpend(inPeriod(txns, _period, now: now));
    final slices = <Slice>[];
    for (var i = 0; i < math.min(_maxSlices, tags.length); i++) {
      slices.add((
        label: tags[i].tag.label,
        value: tags[i].amount,
        color: p.step(i),
      ));
    }
    if (tags.length > _maxSlices) {
      slices.add((
        label: 'Others',
        value: tags
            .skip(_maxSlices)
            .fold<double>(0, (s, t) => s + t.amount),
        color: p.step(_maxSlices),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        ScreenHeader(
            title: 'Insights',
            untagged: untaggedCount(txns),
            onTap: () {}),
        const SizedBox(height: 14),
        PeriodSwitch(
          value: _period,
          onChanged: (v) => setState(() => _period = v),
        ),
        const SizedBox(height: 14),
        _Card(
          title: 'Spending overview',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total spent', style: uiText(size: 12, color: p.inkMuted)),
              const SizedBox(height: 4),
              Text('₹${spent.toStringAsFixed(0)}',
                  style: heroAmount(30, color: p.ink)),
              const SizedBox(height: 6),
              if (change != null)
                Row(
                  children: [
                    Icon(
                      change >= 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 13,
                      color: p.accentInk,
                    ),
                    const SizedBox(width: 3),
                    Text('${(change.abs() * 100).round()}%',
                        style: uiText(
                            size: 12.5,
                            weight: FontWeight.w600,
                            color: p.accentInk)),
                    const SizedBox(width: 5),
                    Text('vs last ${_period.label.toLowerCase()}',
                        style: uiText(size: 12, color: p.inkFaint)),
                  ],
                ),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: _entrance,
                builder: (_, _) => SpendCurve(
                  points: cumulativeSpend(txns, _period, now: now),
                  period: _period,
                  now: now,
                  height: 132,
                  progress: Curves.easeOut.transform(_entrance.value),
                  line: p.accentInk,
                  axis: p.inkFaint,
                  tooltipSurface: p.raised,
                  tooltipInk: p.ink,
                  tooltipMuted: p.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Stat(
                      label: 'Highest day',
                      value: peak == null
                          ? '—'
                          : '₹${peak.amount.toStringAsFixed(0)}',
                      caption: peak == null
                          ? 'nothing yet'
                          : dayLabel(peak.day, now).toLowerCase()),
                  const SizedBox(width: 8),
                  _Stat(
                      label: 'Avg per day',
                      value: '₹${perDay.toStringAsFixed(0)}',
                      caption: 'so far'),
                  const SizedBox(width: 8),
                  _Stat(
                      label: 'Payments',
                      value: '$count',
                      caption: 'this ${_period.label.toLowerCase()}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Spending by tag',
          child: slices.isEmpty
              ? _empty(p, 'Tag a few payments to see this.')
              : Row(
                  children: [
                    AnimatedBuilder(
                      animation: _entrance,
                      builder: (_, _) => DonutChart(
                        slices: slices,
                        total: spent,
                        progress:
                            Curves.easeOutCubic.transform(_entrance.value),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          for (final slice in slices)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: slice.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(slice.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: uiText(
                                            size: 12, color: p.inkMuted)),
                                  ),
                                  Text(
                                    '${(slice.value / spent * 100).round()}%',
                                    style: uiText(
                                        size: 11.5,
                                        color: p.inkFaint),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('₹${slice.value.toStringAsFixed(0)}',
                                      style: uiText(
                                          size: 12,
                                          weight: FontWeight.w600,
                                          color: p.ink)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Spending by account',
          child: _ByAccount(
            txns: inPeriod(txns, _period, now: now),
            progress: _entrance,
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Cashflow',
          child: _Cashflow(
            days: cashflowSeries(txns, _period, now: now),
            income: sumIn(txns, _period, TxnType.credit, now: now),
            expense: sumIn(txns, _period, TxnType.debit, now: now),
          ),
        ),
      ],
    );
  }

  Widget _empty(Palette p, String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Text(message,
              textAlign: TextAlign.center,
              style: uiText(size: 12.5, color: p.inkFaint)),
        ),
      );
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: uiText(
                  size: 13.5, weight: FontWeight.w600, color: p.ink)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String caption;

  const _Stat({
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        decoration: BoxDecoration(
          color: p.ground,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: uiText(size: 10.5, color: p.inkFaint)),
            const SizedBox(height: 5),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: uiText(
                    size: 15, weight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 2),
            Text(caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: uiText(size: 10, color: p.inkFaint)),
          ],
        ),
      ),
    );
  }
}

class _ByAccount extends StatelessWidget {
  final List<Txn> txns;
  final Animation<double> progress;

  const _ByAccount({required this.txns, required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final totals = <String, double>{};
    for (final txn in txns) {
      if (txn.type != TxnType.debit) continue;
      totals[txn.bank] = (totals[txn.bank] ?? 0) + txn.amount;
    }
    if (totals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('Nothing spent this period.',
              style: uiText(size: 12.5, color: p.inkFaint)),
        ),
      );
    }

    final rows = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sum = rows.fold<double>(0, (s, e) => s + e.value);

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(rows[i].key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: uiText(size: 12.5, color: p.inkMuted)),
                    ),
                    Text('₹${rows[i].value.toStringAsFixed(0)}',
                        style: uiText(
                            size: 12.5,
                            weight: FontWeight.w600,
                            color: p.ink)),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: progress,
                  builder: (_, _) => Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Stack(
                            children: [
                              Container(height: 5, color: p.line),
                              FractionallySizedBox(
                                widthFactor: (rows[i].value /
                                        sum *
                                        Curves.easeOutCubic
                                            .transform(progress.value))
                                    .clamp(0.0, 1.0),
                                child: Container(
                                    height: 5, color: p.step(i)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${(rows[i].value / sum * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: uiText(size: 11, color: p.inkFaint),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cashflow extends StatelessWidget {
  final List<CashflowDay> days;
  final double income;
  final double expense;

  const _Cashflow({
    required this.days,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      children: [
        SizedBox(
          height: 116,
          child: days.length < 2
              ? Center(
                  child: Text('Not enough days yet.',
                      style: uiText(size: 12.5, color: p.inkFaint)),
                )
              : CustomPaint(
                  size: Size.infinite,
                  painter: _CashflowPainter(
                    days: days,
                    // Two steps apart on the ramp, and both directly labelled
                    // below — a monochrome chart cannot separate them by hue.
                    incomeColor: p.step(0),
                    expenseColor: p.step(3),
                    axis: p.inkFaint,
                    grid: p.line,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Legend(
                color: p.step(0),
                label: 'Income',
                value: '₹${income.toStringAsFixed(0)}'),
            const SizedBox(width: 10),
            _Legend(
                color: p.step(3),
                label: 'Expense',
                value: '₹${expense.toStringAsFixed(0)}'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.ground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: uiText(size: 10.5, color: p.inkFaint)),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiText(
                          size: 13, weight: FontWeight.w600, color: p.ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashflowPainter extends CustomPainter {
  final List<CashflowDay> days;
  final Color incomeColor;
  final Color expenseColor;
  final Color axis;
  final Color grid;

  _CashflowPainter({
    required this.days,
    required this.incomeColor,
    required this.expenseColor,
    required this.axis,
    required this.grid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 18.0;
    final h = size.height - bottom;
    var peak = 0.0;
    for (final d in days) {
      peak = math.max(peak, math.max(d.income, d.expense));
    }
    if (peak <= 0) peak = 1;

    canvas.drawLine(
      Offset(0, h),
      Offset(size.width, h),
      Paint()..color = grid,
    );

    Path pathFor(double Function(CashflowDay) pick) {
      final path = Path();
      for (var i = 0; i < days.length; i++) {
        final x = days.length == 1
            ? size.width / 2
            : (i / (days.length - 1)) * size.width;
        final y = h - (pick(days[i]) / peak) * (h - 8);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      return path;
    }

    void stroke(Path path, Color color) => canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );

    stroke(pathFor((d) => d.expense), expenseColor);
    stroke(pathFor((d) => d.income), incomeColor);

    void label(String text, double x, TextAlign align) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: uiText(size: 10, color: axis)),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = switch (align) {
        TextAlign.right => x - tp.width,
        _ => x,
      };
      tp.paint(canvas, Offset(dx, h + 5));
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String fmt(DateTime d) => '${d.day} ${months[d.month - 1]}';
    label(fmt(days.first.day), 0, TextAlign.left);
    if (days.length > 1) {
      label(fmt(days.last.day), size.width, TextAlign.right);
    }
  }

  @override
  bool shouldRepaint(_CashflowPainter old) =>
      old.days != days || old.incomeColor != incomeColor;
}
