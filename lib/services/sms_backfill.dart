import 'package:another_telephony/telephony.dart';

import 'sms_parser.dart';
import 'transactions_db.dart';

const backfillWindow = Duration(days: 30);

/// Imports transactions from bank SMS already sitting in the inbox.
///
/// The live listener only sees messages that arrive after capture is enabled,
/// so without this everything before setup (or before a reinstall) is lost.
///
/// Deliberately writes through [TransactionsDb.insertIfNew] rather than the
/// shared capture path: a month of history must not raise a month of overlay
/// popups. Imported rows land untagged and are tagged from the list screen.
///
/// Idempotent — re-running imports only what de-duplication has not already
/// seen, so a rescan after a parser fix is safe.
Future<int> backfillRecentSms({
  Telephony? telephony,
  Duration window = backfillWindow,
}) async {
  final since = DateTime.now().subtract(window);
  final messages = await (telephony ?? Telephony.instance).getInboxSms(
    columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
    filter: SmsFilter.where(SmsColumn.DATE)
        .greaterThan(since.millisecondsSinceEpoch.toString()),
    sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.ASC)],
  );

  var imported = 0;
  for (final message in messages) {
    if (message.date == null) continue;
    final txn = parseBankSms(
      message.address ?? '',
      message.body ?? '',
      DateTime.fromMillisecondsSinceEpoch(message.date!),
    );
    if (txn == null) continue;
    if (await TransactionsDb.instance.insertIfNew(txn) != null) imported++;
  }
  return imported;
}

/// Runs the backfill once per install. Safe to call on every launch.
Future<int?> backfillIfFirstRun() async {
  if (await TransactionsDb.instance.isBackfillDone()) return null;
  final imported = await backfillRecentSms();
  await TransactionsDb.instance.markBackfillDone();
  return imported;
}
