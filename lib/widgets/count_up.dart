import 'package:flutter/material.dart';

/// Tweens between amounts so switching period reads as the same number moving,
/// not a different number appearing. Skipped entirely when the platform asks
/// for reduced motion.
class CountUp extends StatelessWidget {
  final double value;
  final TextStyle style;
  final Duration duration;

  /// Style for the paise. Given one, the amount renders as "₹1,842.56" with the
  /// fraction set apart, so the rupees stay the thing you read first.
  final TextStyle? fractionStyle;

  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.fractionStyle,
    this.duration = const Duration(milliseconds: 650),
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) return _text(value);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => _text(v),
    );
  }

  Widget _text(double v) {
    final fraction = fractionStyle;
    // Truncated, not rounded: showing ".00" on ₹1,842.99 would be a lie about
    // a number sitting right next to it.
    final paiseValue = (v.abs() * 100).floor() % 100;
    // Most amounts here are whole rupees, and a permanent ".00" is noise
    // pretending to be precision.
    if (fraction == null || paiseValue == 0) {
      return Text(_format(v, round: fraction == null), style: style);
    }
    final paise = paiseValue.toString().padLeft(2, '0');
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: _format(v, round: false)),
          TextSpan(text: '.$paise', style: fraction),
        ],
      ),
    );
  }

  static String _format(double v, {bool round = true}) {
    final whole = (round ? v.round() : v.truncate()).toString();
    // Indian grouping: last three digits, then pairs — 1,23,456 not 123,456.
    if (whole.length <= 3) return '₹$whole';
    final head = whole.substring(0, whole.length - 3);
    final tail = whole.substring(whole.length - 3);
    final buffer = StringBuffer();
    for (var i = 0; i < head.length; i++) {
      if (i > 0 && (head.length - i) % 2 == 0) buffer.write(',');
      buffer.write(head[i]);
    }
    return '₹$buffer,$tail';
  }
}
