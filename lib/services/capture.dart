import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../models/transaction.dart';
import 'transactions_db.dart';

/// The id the overlay should tag, handed over through the database.
///
/// The overlay runs in a second Flutter engine that takes an unknown time to
/// boot. Passing the payload with `shareData` after a fixed delay raced that
/// boot and, when it lost, left an empty overlay on screen — see
/// [captureTransaction].
const pendingKey = 'capture:pending';

/// Whether the "watch for transactions" explainer is worth raising.
///
/// The old check also required capture to already be *running*, which is never
/// true during the first frame — so the dialog appeared on every launch even
/// with every permission granted.
bool shouldAskForCapture({
  required bool overlay,
  required bool notifications,
  required bool askedBefore,
}) {
  if (overlay && notifications) return false;
  return !askedBefore;
}

/// Saves a captured transaction and raises the tagging popup.
///
/// Shared by both capture sources so de-duplication and the popup behave
/// identically whether the transaction arrived as a bank SMS or a payment-app
/// notification.
Future<void> captureTransaction(Txn txn) async {
  final id = await TransactionsDb.instance.insertIfNew(txn);
  if (id == null) return; // already captured from the other source

  if (!await FlutterOverlayWindow.isPermissionGranted()) return;

  // A second payment mid-popup used to re-enter the service and swap the view
  // out from under the one being tagged. This one is saved either way; it just
  // waits in the untagged list.
  if (await FlutterOverlayWindow.isActive()) return;

  await TransactionsDb.instance.setMeta(pendingKey, '$id');

  // Not focusable. `OverlayFlag.focusPointer` maps to FLAG_NOT_TOUCH_MODAL
  // alone, which leaves a focusable window sitting above every app — the
  // system keyboard then binds to the overlay and no other app can raise it.
  // The form escalates the flag itself when the reason field is tapped.
  await FlutterOverlayWindow.showOverlay(
    height: 380,
    width: WindowSize.matchParent,
    alignment: OverlayAlignment.bottomCenter,
    flag: OverlayFlag.defaultFlag,
    enableDrag: false,
  );
}

/// Closes the popup and forgets what it was for.
///
/// Called on submit, on cancel, on the idle timeout, and whenever the app
/// itself comes to the front — an overlay that outlives its moment is the one
/// that wedges the keyboard.
Future<void> dismissOverlay() async {
  await TransactionsDb.instance.deleteMeta(pendingKey);
  if (!await FlutterOverlayWindow.isActive()) return;
  // Drop focus before the window goes, so a failed close cannot leave a
  // focusable window behind.
  await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
  await FlutterOverlayWindow.closeOverlay();
}
