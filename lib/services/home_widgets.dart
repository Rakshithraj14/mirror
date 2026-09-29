import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/profile.dart';
import '../models/transaction.dart';
import '../theme.dart';
import 'analytics.dart';
import 'upi.dart';

/// Android class names, matched by `updateWidget` to the providers in
/// `android/app/src/main/kotlin/com/example/penny/`.
const _todayWidget = 'com.example.penny.TodayWidget';
const _qrWidget = 'com.example.penny.QrWidget';

final _rupees = NumberFormat.decimalPattern('en_IN');
String _money(double v) => '₹${_rupees.format(v.round())}';
String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// What the Today widget shows, already formatted: the native side only
/// places strings, so formatting lives in one language.
///
/// The average is over the days *before* today, so today's spending never
/// drags its own yardstick. It looks back at most 30 days, and only as far as
/// the first payment on record, so a week-old install is not averaged over
/// 23 empty days.
typedef TodaySnapshot = ({
  String day,
  String spent,
  String average,
  String untagged,
});

TodaySnapshot todaySnapshot(List<Txn> txns, DateTime now) {
  final today = startOfDay(now);
  double spent = 0;
  double before = 0;
  DateTime? earliest;
  for (final t in txns) {
    if (earliest == null || t.time.isBefore(earliest)) earliest = t.time;
    if (t.type != TxnType.debit) continue;
    if (!t.time.isBefore(today)) {
      spent += t.amount;
    } else if (!t.time.isBefore(today.subtract(const Duration(days: 30)))) {
      before += t.amount;
    }
  }

  final history =
      earliest == null ? 0 : today.difference(startOfDay(earliest)).inDays;
  final days = history.clamp(0, 30);
  final untagged = untaggedCount(txns);

  return (
    day: _dayKey(now),
    spent: _money(spent),
    average: days == 0 ? '' : 'avg ${_money(before / days)}/day',
    untagged: untagged == 0 ? '' : '$untagged untagged',
  );
}

/// Pushes the Today numbers to the home screen.
///
/// Called from the app, from background capture and from the tagging popup.
/// Never throws: a widget that failed to refresh must not cost a captured
/// payment or a tag.
Future<void> refreshTodayWidget(List<Txn> txns) async {
  if (kIsWeb) return;
  try {
    final s = todaySnapshot(txns, DateTime.now());
    await HomeWidget.saveWidgetData('today_day', s.day);
    await HomeWidget.saveWidgetData('today_spent', s.spent);
    await HomeWidget.saveWidgetData('today_average', s.average);
    await HomeWidget.saveWidgetData('today_untagged', s.untagged);
    await HomeWidget.updateWidget(qualifiedAndroidName: _todayWidget);
  } catch (e) {
    debugPrint('Today widget not refreshed: $e');
  }
}

/// What the QR image was last drawn for, so it is redrawn only when the
/// name or UPI ID actually changes rather than on every reload.
String? _qrDrawnFor;

/// Draws the receive QR card to a PNG the native widget displays.
///
/// Rendered by Flutter rather than natively so the widget carries the same
/// card, font and QR as the app, with no second QR library. Needs a live
/// view, so this only ever runs from the app, which is the only place the
/// name and UPI ID can change anyway.
Future<void> refreshQrWidget(Profile profile) async {
  if (kIsWeb) return;
  final key = profile.hasUpi ? '${profile.display}|${profile.upi}' : '';
  if (key == _qrDrawnFor) return;
  try {
    if (profile.hasUpi) {
      await HomeWidget.renderFlutterWidget(
        QrWidgetCard(name: profile.display, upi: profile.upi!),
        key: 'qr_image',
        logicalSize: QrWidgetCard.size,
        // 360×420 px. The launcher receives the bitmap over a binder call
        // capped near 1 MB, so this is deliberately not device resolution.
        pixelRatio: 2,
      );
    } else {
      await HomeWidget.saveWidgetData<String>('qr_image', null);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: _qrWidget);
    _qrDrawnFor = key;
  } catch (e) {
    debugPrint('QR widget not refreshed: $e');
  }
}

/// The home-screen QR: no amount, so the payer types it and one image serves
/// every payment. White for the same reason as the in-app ticket.
class QrWidgetCard extends StatelessWidget {
  final String name;
  final String upi;

  const QrWidgetCard({super.key, required this.name, required this.upi});

  static const size = Size(180, 210);
  static const _ink = Color(0xFF101110);
  static const _muted = Color(0xFF63665E);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: uiText(size: 13, weight: FontWeight.w700, color: _ink)),
          Text(upi,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: uiText(size: 9.5, color: _muted)),
          const SizedBox(height: 8),
          Expanded(
            child: QrImageView(
              data: upiPayUri(upiId: upi, name: name),
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Palette.dark.ramp.last,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('SCAN TO PAY',
              style: uiText(
                  size: 8.5,
                  spacing: 1.8,
                  weight: FontWeight.w600,
                  color: Palette.dark.ramp.last)),
        ],
      ),
    );
  }
}
