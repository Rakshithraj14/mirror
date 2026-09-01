import 'package:flutter/material.dart';

import '../theme.dart';

/// Daily spend over a trailing window.
///
/// One series, so it carries no legend — the title above names it. Only the
/// peak is labelled; a number on every point would be noise.
///
// ponytail: hand-drawn painter rather than a chart dependency — one line, no
// axes to speak of. Reach for fl_chart if this ever needs zoom or multi-series.
class SpendChart extends StatelessWidget {
  final List<double> daily;
  final double height;

  const SpendChart({super.key, required this.daily, this.height = 160});

  @override
  Widget build(BuildContext context) {
    final peak = daily.isEmpty ? 0.0 : daily.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: peak <= 0
          ? const Center(
              child: Text('No spending in the last 30 days',
                  style: TextStyle(color: YumekoColors.inkMuted, fontSize: 12)),
            )
          : CustomPaint(painter: _SpendPainter(daily: daily, peak: peak)),
    );
  }
}

class _SpendPainter extends CustomPainter {
  final List<double> daily;
  final double peak;

  _SpendPainter({required this.daily, required this.peak});

  @override
  void paint(Canvas canvas, Size size) {
    if (daily.length < 2) return;

    // Leave room on the right so the peak label never clips the edge.
    const topPad = 18.0;
    const bottomPad = 4.0;
    final plotHeight = size.height - topPad - bottomPad;

    double xAt(int i) => size.width * (i / (daily.length - 1));
    double yAt(double v) => topPad + plotHeight * (1 - (v / peak));

    // Recessive gridlines: present for reading values, never competing.
    final grid = Paint()
      ..color = const Color(0xFF26262F)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = topPad + plotHeight * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Path()..moveTo(xAt(0), yAt(daily[0]));
    for (var i = 1; i < daily.length; i++) {
      line.lineTo(xAt(i), yAt(daily[i]));
    }

    final fill = Path.from(line)
      ..lineTo(xAt(daily.length - 1), topPad + plotHeight)
      ..lineTo(xAt(0), topPad + plotHeight)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x45B39DFF), Color(0x00B39DFF)],
        ).createShader(Rect.fromLTWH(0, topPad, size.width, plotHeight)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = YumekoColors.accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    _labelPeak(canvas, size, xAt, yAt);
  }

  void _labelPeak(Canvas canvas, Size size, double Function(int) xAt,
      double Function(double) yAt) {
    final peakIndex = daily.indexOf(peak);
    final peakOffset = Offset(xAt(peakIndex), yAt(peak));

    canvas.drawCircle(
        peakOffset, 3.5, Paint()..color = YumekoColors.accent);

    final label = TextPainter(
      text: TextSpan(
        text: '₹${peak.toStringAsFixed(0)}',
        style: const TextStyle(color: YumekoColors.inkMuted, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Flip the label inward near the edges so it stays on canvas.
    final dx = (peakOffset.dx - label.width / 2)
        .clamp(0.0, size.width - label.width);
    label.paint(canvas, Offset(dx, (peakOffset.dy - 16).clamp(0.0, size.height)));
  }

  @override
  bool shouldRepaint(_SpendPainter old) =>
      old.daily != daily || old.peak != peak;
}
