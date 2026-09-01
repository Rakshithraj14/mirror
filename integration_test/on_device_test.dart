// Runs on a real Android device against real Android sqflite — the host-side
// DB tests use desktop SQLite via FFI, which does not exercise the Android
// plugin or the on-device schema migration.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:penny/models/transaction.dart';
import 'package:penny/services/sms_parser.dart';
import 'package:penny/services/transactions_db.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Never run against the real database — these tests delete it between cases.
  TransactionsDb.dbName = 'yumeko_test.db';

  final at = DateTime(2026, 8, 26, 12, 0);

  setUp(() async {
    await TransactionsDb.instance.resetForTest();
  });

  group('real device database', () {
    test('captures a parsed Canara debit end to end', () async {
      final txn = parseBankSms(
        'AD-CANBNK',
        'Dear Customer, Acct XXX489 Dr. INR 190.00 on 01/07/26 to SHASHIKANTA; '
            'UPI: 618239653510; Bal INR 98.75.Not you?SMS BLOCKUPI to '
            '9901771222-CanaraBank',
        at,
      );
      expect(txn, isNotNull);

      final id = await TransactionsDb.instance.insertIfNew(txn!);
      expect(id, isNotNull);

      final saved = (await TransactionsDb.instance.getAll()).single;
      expect(saved.type, TxnType.debit);
      expect(saved.amount, 190.00);
      expect(saved.bank, 'Canara Bank');
      expect(saved.source, TxnSource.sms);
    });

    test('de-duplicates a notification then SMS for one transaction', () async {
      final fromApp = parsePaymentNotification(
        'com.phonepe.app',
        'Payment successful',
        'You paid ₹190 to SHASHIKANTA',
        at,
      );
      expect(fromApp, isNotNull);
      expect(await TransactionsDb.instance.insertIfNew(fromApp!), isNotNull);

      final fromSms = parseBankSms(
        'AD-CANBNK',
        'Dear Customer, Acct XXX489 Dr. INR 190.00 on 26/08/26 to SHASHIKANTA; '
            'UPI: 618239653510; Bal INR 98.75-CanaraBank',
        at.add(const Duration(seconds: 15)),
      );
      expect(fromSms, isNotNull);
      expect(await TransactionsDb.instance.insertIfNew(fromSms!), isNull,
          reason: 'second source must not raise a second popup');

      final saved = (await TransactionsDb.instance.getAll()).single;
      expect(saved.bank, 'Canara Bank', reason: 'SMS upgrades the app name');
    });

    test('tagging survives a database reopen', () async {
      final id = await TransactionsDb.instance.insertIfNew(Txn(
        bank: 'Canara Bank',
        amount: 42,
        type: TxnType.debit,
        time: at,
        source: TxnSource.sms,
        rawSender: 'AD-CANBNK',
        rawBody: 'raw',
      ));
      await TransactionsDb.instance.tag(id!, 'family', 'groceries');

      // Force a close/reopen so the assertion reads from disk, not cache.
      await TransactionsDb.instance.reopenForTest();

      final saved = (await TransactionsDb.instance.getAll()).single;
      expect(saved.category, 'family');
      expect(saved.reason, 'groceries');
    });
  });

  test('upgrades a v1 database without losing rows', () async {
    // Build a v1 schema (no `source` column) exactly as shipped before
    // notification capture existed, then let the app open it.
    await TransactionsDb.instance.resetForTest();
    final path = p.join(await getDatabasesPath(), TransactionsDb.dbName);
    final legacy = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bank TEXT NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          timestampMillis INTEGER NOT NULL,
          rawSender TEXT NOT NULL,
          rawBody TEXT NOT NULL,
          category TEXT,
          reason TEXT
        )
      '''),
    );
    await legacy.insert('transactions', {
      'bank': 'Canara Bank',
      'amount': 1000.0,
      'type': 'credit',
      'timestampMillis': at.millisecondsSinceEpoch,
      'rawSender': 'AD-CANBNK',
      'rawBody': 'legacy row',
      'category': 'personal',
      'reason': 'gift',
    });
    await legacy.close();

    final rows = await TransactionsDb.instance.getAll();
    expect(rows.length, 1, reason: 'migration must not drop existing rows');
    expect(rows.single.source, TxnSource.sms, reason: 'old rows default to sms');
    expect(rows.single.reason, 'gift');
  });
}
