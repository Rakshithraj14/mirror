import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../theme.dart';

/// The running spend curve, drawn white over the hero card's gradient.
///
/// Touch anywhere along it to move the read-out; it rests on the latest point
/// so the card is never a chart without a number attached to it.
class SpendCurve extends StatefulWidget {
  final List<SpendPoint> points;
  final Period period;
  final DateTime now;
  final double progress;

  /// The colour the line is drawn in, and the ink used on the read-out card.
  final Color line;
  final Color axis;
  final Color tooltipSurface;
  final Color tooltipInk;
  final Color tooltipMuted;
  final double height;

  const SpendCurve({
    super.key,
    required this.points,
    required this.period,
    required this.now,
    required this.line,
    required this.axis,
    required this.tooltipSurface,
    required this.tooltipInk,
    required this.tooltipMuted,
    this.height = 150,
    this.progress = 1,
  });

  @override
  State<SpendCurve> createState() => _SpendCurveState();
}

class _SpendCurveState extends State<SpendCurve> {
  /// Null means "rest on the last point" rather than "nothing selected", so the
  /// tooltip survives a period switch without needing to be re-pinned.
  int? _touched;

  void _selectAt(double dx, double width) {
    final points = widget.points;
    if (points.length < 2) return;
    final from = points.first.at.millisecondsSinceEpoch;
    final span = points.last.at.millisecondsSinceEpoch - from;
    if (span <= 0) return;

    final t = (dx / width).clamp(0.0, 1.0);
    final target = from + (span * t);
    var nearest = 0;
    var best = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = (points[i].at.millisecondsSinceEpoch - target).abs().toDouble();
      if (d < best) {
        best = d;
        nearest = i;
      }
    }
    if (nearest != _touched) setState(() => _touched = nearest);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: points.length < 2
          ? Center(
              child: Text(
                'Nothing spent yet in this period',
                style: uiText(size: 12, color: widget.axis),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _selectAt(d.localPosition.dx, constraints.maxWidth),
                onHorizontalDragStart: (d) =>
                    _selectAt(d.localPosition.dx, constraints.maxWidth),
                onHorizontalDragUpdate: (d) =>
                    _selectAt(d.localPosition.dx, constraints.maxWidth),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _CurvePainter(
                    points: points,
                    period: widget.period,
                    now: widget.now,
                    progress: widget.progress,
                    selected: _touched ?? points.length - 1,
                    line: widget.line,
                    axis: widget.axis,
                    tooltipSurface: widget.tooltipSurface,
                    tooltipInk: widget.tooltipInk,
                    tooltipMuted: widget.tooltipMuted,
                  ),
                ),
              ),
            ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  final List<SpendPoint> points;
  final Period period;
  final DateTime now;
  final double progress;
  final int selected;
  final Color line;
  final Color axis;
  final Color tooltipSurface;
  final Color tooltipInk;
  final Color tooltipMuted;

  _CurvePainter({
    required this.points,
    required this.period,
    required this.now,
    required this.progress,
    required this.selected,
    required this.line,
    required this.axis,
    required this.tooltipSurface,
    required this.tooltipInk,
    required this.tooltipMuted,
  });

  static const _axisHeight = 20.0;
  static const _topInset = 34.0; // headroom for the tooltip card

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height - _axisHeight;
    final from = points.first.at.millisecondsSinceEpoch;
    final span = points.last.at.millisecondsSinceEpoch - from;
    final peak = points.last.total;
    if (span <= 0 || peak <= 0) {
      _drawAxis(canvas, size, baseline);
      return;
    }

    double xOf(SpendPoint p) =>
        ((p.at.millisecondsSinceEpoch - from) / span) * size.width;
    double yOf(SpendPoint p) =>
        baseline - (p.total / peak) * (baseline - _topInset);

    _drawAxis(canvas, size, baseline);

    // Straight segments, never smoothed: each payment stays a visible kink,
    // and a spline would invent spending between two of them.
    final drawn = math.max(2, (points.length * progress.clamp(0.0, 1.0)).ceil());
    final visible = points.take(drawn).toList();
    final path = Path()..moveTo(xOf(visible.first), yOf(visible.first));
    for (final p in visible.skip(1)) {
      path.lineTo(xOf(p), yOf(p));
    }

    final area = Path.from(path)
      ..lineTo(xOf(visible.last), baseline)
      ..lineTo(xOf(visible.first), baseline)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.22), line.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, _topInset, size.width, baseline)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    if (progress < 1) return; // the read-out lands once the line has drawn
    final point = points[selected.clamp(0, points.length - 1)];
    final px = xOf(point);
    final py = yOf(point);
    canvas
      ..drawCircle(
          Offset(px, py), 7, Paint()..color = line.withValues(alpha: 0.35))
      ..drawCircle(Offset(px, py), 4.5, Paint()..color = line);
    _drawTooltip(canvas, size, px, py, point);
  }

  void _drawTooltip(
      Canvas canvas, Size size, double px, double py, SpendPoint point) {
    final amount = TextPainter(
      text: TextSpan(
        text: '₹${point.total.round()}',
        style: heroAmount(19, color: tooltipInk),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final when = TextPainter(
      text: TextSpan(
        text: _tooltipLabel(point.at),
        style: uiText(size: 11, color: tooltipMuted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 12.0;
    const padV = 9.0;
    final w = math.max(amount.width, when.width) + padH * 2;
    final h = amount.height + when.height + padV * 2 + 3;

    // Clamped inside the chart, and flipped below the point when the curve has
    // climbed too near the top to fit a card above it.
    final left = (px - w / 2).clamp(0.0, size.width - w);
    final above = py - h - 14;
    final top = above < 0 ? py + 14 : above;
    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, w, h), const Radius.circular(13));

    canvas
      ..drawRRect(rect.shift(const Offset(0, 3)),
          Paint()..color = const Color(0x33000000))
      ..drawRRect(rect, Paint()..color = tooltipSurface);
    amount.paint(canvas, Offset(left + padH, top + padV));
    when.paint(canvas, Offset(left + padH, top + padV + amount.height + 3));
  }

  String _tooltipLabel(DateTime d) {
    if (period == Period.today) {
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      return 'by $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
    }
    return 'by ${d.day} ${_months[d.month - 1]}';
  }

  /// Ticks frame the whole period, not just the part that has happened, so a
  /// week reads as "two days in" rather than as a full week of flat spending.
  void _drawAxis(Canvas canvas, Size size, double baseline) {
    final from = points.first.at;
    final to = period.end(now);
    final span = to.difference(from).inMilliseconds;
    if (span <= 0) return;

    final labels = switch (period) {
      Period.today => [
          for (final h in const [6, 12, 18])
            (from.add(Duration(hours: h)), h == 12 ? '12p' : '${h % 12}${h < 12 ? 'a' : 'p'}'),
        ],
      Period.week => [
          for (var i = 0; i < 7; i++)
            (from.add(Duration(days: i)), _weekdays[from.add(Duration(days: i)).weekday - 1]),
        ],
      Period.month => [
          for (final d in const [1, 5, 10, 15, 20, 25])
            (DateTime(from.year, from.month, d), '$d'),
          (DateTime(to.year, to.month, to.day).subtract(const Duration(days: 1)),
              '${DateTime(to.year, to.month, 0).day}'),
        ],
    };

    for (final (at, text) in labels) {
      final t = at.difference(from).inMilliseconds / span;
      if (t < 0 || t > 1) continue;
      final x = t * size.width;

      canvas.drawLine(
        Offset(x, _topInset),
        Offset(x, baseline),
        Paint()..color = axis.withValues(alpha: 0.18),
      );
      final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: uiText(size: 10, color: axis)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((x - tp.width / 2).clamp(0.0, size.width - tp.width), baseline + 6),
      );
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.points != points ||
      old.period != period ||
      old.line != line;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
