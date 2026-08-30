import 'package:flutter_notification_listener/flutter_notification_listener.dart';

import 'capture.dart';
import 'sms_parser.dart';

Future<bool> isNotificationAccessGranted() async =>
    await NotificationsListener.hasPermission ?? false;

/// Opens the system "Notification access" page. Like the overlay permission,
/// this is a settings toggle rather than a runtime dialog, so the caller
/// re-checks when the user returns instead of awaiting a result.
Future<void> openNotificationAccessSettings() async =>
    NotificationsListener.openPermissionSettings();

/// Starts the listener service. [_onNotification] runs in its own background
/// isolate, so notifications are still captured when the app is closed.
Future<void> startNotificationListening() async {
  NotificationsListener.initialize(callbackHandle: _onNotification);
  if (await NotificationsListener.isRunning ?? false) return;
  await NotificationsListener.startService(
    foreground: true,
    title: 'Yumeko',
    description: 'Watching for transactions',
  );
}

@pragma('vm:entry-point')
void _onNotification(NotificationEvent event) {
  final packageName = event.packageName;
  if (packageName == null) return;

  final txn = parsePaymentNotification(
    packageName,
    event.title,
    event.text,
    event.createAt ?? DateTime.now(),
  );
  if (txn == null) return;

  captureTransaction(txn);
}
