import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

typedef Slice = ({String label, double value, Color color});

/// Share of spend, with the total in the middle.
///
/// Slices are lightness steps of the one accent hue rather than separate
/// colours, so every slice is also named in the legend beside it — in a
/// monochrome palette the ring alone cannot carry identity.
class DonutChart extends StatelessWidget {
  final List<Slice> slices;
  final double total;
  final double progress;
  final double size;

  const DonutChart({
    super.key,
    required this.slices,
    required this.total,
    this.progress = 1,
    this.size = 132,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          slices: slices,
          progress: progress,
          track: p.line,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('₹${_short(total)}',
                  style: heroAmount(19, color: p.ink)),
              const SizedBox(height: 2),
              Text('Total', style: uiText(size: 10.5, color: p.inkFaint)),
            ],
          ),
        ),
      ),
    );
  }

  static String _short(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _DonutPainter extends CustomPainter {
  final List<Slice> slices;
  final double progress;
  final Color track;

  _DonutPainter({
    required this.slices,
    required this.progress,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 20.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke,
        size.height - stroke);
    final total = slices.fold<double>(0, (s, x) => s + x.value);

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (total <= 0) return;

    // A 2px gap between segments, so adjacent lightness steps stay countable.
    const gap = 0.035;
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * math.pi * 2 * progress;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0, sweep - gap),
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.slices != slices || old.track != track;
}
