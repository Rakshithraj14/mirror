import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../models/transaction.dart';
import 'transactions_db.dart';

/// Saves a captured transaction and raises the tagging popup.
///
/// Shared by both capture sources so de-duplication and the popup behave
/// identically whether the transaction arrived as a bank SMS or a payment-app
/// notification.
Future<void> captureTransaction(Txn txn) async {
  final id = await TransactionsDb.instance.insertIfNew(txn);
  if (id == null) return; // already captured from the other source

  if (!await FlutterOverlayWindow.isPermissionGranted()) return;

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
