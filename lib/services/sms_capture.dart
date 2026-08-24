import 'package:another_telephony/telephony.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'sms_parser.dart';
import 'transactions_db.dart';

final Telephony _telephony = Telephony.instance;

Future<bool> requestSmsAndOverlayPermissions() async {
  final smsGranted = await _telephony.requestSmsPermissions ?? false;
  if (!smsGranted) return false;
  final overlayGranted = await FlutterOverlayWindow.requestPermission() ?? false;
  return overlayGranted;
}

void startSmsListening() {
  _telephony.listenIncomingSms(
    onNewMessage: _handleMessage,
    onBackgroundMessage: handleBackgroundSms,
  );
}

@pragma('vm:entry-point')
Future<void> handleBackgroundSms(SmsMessage message) async {
  await _handleMessage(message);
}

Future<void> _handleMessage(SmsMessage message) async {
  final sender = message.address ?? '';
  final body = message.body ?? '';
  final receivedAt = message.date != null
      ? DateTime.fromMillisecondsSinceEpoch(message.date!)
      : DateTime.now();

  final txn = parseBankSms(sender, body, receivedAt);
  if (txn == null) return;

  final id = await TransactionsDb.instance.insert(txn);

  final canOverlay = await FlutterOverlayWindow.isPermissionGranted();
  if (!canOverlay) return;

  await FlutterOverlayWindow.showOverlay(
    height: 380,
    width: WindowSize.matchParent,
    alignment: OverlayAlignment.bottomCenter,
    flag: OverlayFlag.focusPointer,
    enableDrag: false,
  );

  // The overlay's Flutter engine needs a beat to start listening before
  // shareData reaches it, otherwise the first message is dropped.
  await Future.delayed(const Duration(milliseconds: 400));

  await FlutterOverlayWindow.shareData({
    'id': id,
    'bank': txn.bank,
    'amount': txn.amount,
    'type': txn.type.name,
    'timestampMillis': txn.time.millisecondsSinceEpoch,
  });
}
