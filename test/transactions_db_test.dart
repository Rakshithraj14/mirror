import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/transaction.dart';
import 'package:penny/services/transactions_db.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Txn txn({
  required double amount,
  required TxnType type,
  required TxnSource source,
  required DateTime time,
  String bank = 'Canara Bank',
  String? upiRef,
}) =>
    Txn(
      bank: bank,
      amount: amount,
      type: type,
      time: time,
      source: source,
      rawSender: source == TxnSource.sms ? 'AD-CANBNK' : 'com.phonepe.app',
      rawBody: 'raw',
      upiRef: upiRef,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Test files run concurrently and would otherwise share one database file.
    TransactionsDb.dbName = 'yumeko_db_test.db';
  });

  setUp(() async {
    await TransactionsDb.instance.resetForTest();
  });

  final at = DateTime(2026, 8, 26, 12, 0);

  test('inserts a transaction that has no duplicate', () async {
    final id = await TransactionsDb.instance.insertIfNew(
      txn(amount: 500, type: TxnType.debit, source: TxnSource.sms, time: at),
    );

    expect(id, isNotNull);
    expect((await TransactionsDb.instance.getAll()).length, 1);
  });

  test('drops the second report of the same transaction', () async {
    await TransactionsDb.instance.insertIfNew(txn(
        amount: 500,
        type: TxnType.debit,
        source: TxnSource.notification,
        time: at));
    final id = await TransactionsDb.instance.insertIfNew(txn(
        amount: 500,
        type: TxnType.debit,
        source: TxnSource.sms,
        time: at.add(const Duration(seconds: 20))));

    expect(id, isNull, reason: 'no second popup for one transaction');
    expect((await TransactionsDb.instance.getAll()).length, 1);
  });

  test('a later SMS upgrades the app name to the real bank name', () async {
    await TransactionsDb.instance.insertIfNew(txn(
      amount: 500,
      type: TxnType.debit,
      source: TxnSource.notification,
      time: at,
      bank: 'PhonePe',
    ));
    await TransactionsDb.instance.insertIfNew(txn(
      amount: 500,
      type: TxnType.debit,
      source: TxnSource.sms,
      time: at.add(const Duration(seconds: 20)),
      bank: 'Canara Bank',
    ));

    final saved = (await TransactionsDb.instance.getAll()).single;
    expect(saved.bank, 'Canara Bank');
    expect(saved.source, TxnSource.sms);
  });

  test('keeps an opposite-direction transaction of the same amount', () async {
    await TransactionsDb.instance.insertIfNew(
        txn(amount: 500, type: TxnType.debit, source: TxnSource.sms, time: at));
    final id = await TransactionsDb.instance.insertIfNew(txn(
        amount: 500,
        type: TxnType.credit,
        source: TxnSource.sms,
        time: at.add(const Duration(seconds: 5))));

    expect(id, isNotNull, reason: 'a refund is not a duplicate of the payment');
    expect((await TransactionsDb.instance.getAll()).length, 2);
  });

  test('keeps an identical amount sent outside the dedupe window', () async {
    await TransactionsDb.instance.insertIfNew(
        txn(amount: 50, type: TxnType.debit, source: TxnSource.sms, time: at));
    final id = await TransactionsDb.instance.insertIfNew(txn(
        amount: 50,
        type: TxnType.debit,
        source: TxnSource.sms,
        time: at.add(const Duration(minutes: 5))));

    expect(id, isNotNull);
    expect((await TransactionsDb.instance.getAll()).length, 2);
  });

  test('tagging preserves the row and marks it tagged', () async {
    final id = await TransactionsDb.instance.insertIfNew(
        txn(amount: 75, type: TxnType.debit, source: TxnSource.sms, time: at));
    await TransactionsDb.instance.tag(id!, TxnCategory.office, 'team lunch');

    final saved = (await TransactionsDb.instance.getAll()).single;
    expect(saved.isTagged, isTrue);
    expect(saved.category, TxnCategory.office);
    expect(saved.reason, 'team lunch');
  });
  group('upi reference de-duplication', () {
    test('matches on reference even outside the time window', () async {
      await TransactionsDb.instance.insertIfNew(txn(
          amount: 500,
          type: TxnType.debit,
          source: TxnSource.notification,
          time: at,
          upiRef: '618239653510'));
      final id = await TransactionsDb.instance.insertIfNew(txn(
          amount: 500,
          type: TxnType.debit,
          source: TxnSource.sms,
          time: at.add(const Duration(hours: 3)),
          upiRef: '618239653510'));

      expect(id, isNull, reason: 'same reference is the same transaction');
      expect((await TransactionsDb.instance.getAll()).length, 1);
    });

    test('keeps two same-value payments with different references', () async {
      await TransactionsDb.instance.insertIfNew(txn(
          amount: 500,
          type: TxnType.debit,
          source: TxnSource.sms,
          time: at,
          upiRef: '111111111111'));
      final id = await TransactionsDb.instance.insertIfNew(txn(
          amount: 500,
          type: TxnType.debit,
          source: TxnSource.sms,
          time: at.add(const Duration(minutes: 1)),
          upiRef: '222222222222'));

      expect(id, isNotNull,
          reason: 'Amazon then Swiggy for the same amount are two payments');
      expect((await TransactionsDb.instance.getAll()).length, 2);
    });

    test('falls back to the window when the earlier row has no reference',
        () async {
      await TransactionsDb.instance.insertIfNew(txn(
          amount: 500,
          type: TxnType.debit,
          source: TxnSource.notification,
          time: at));
      final id = await TransactionsDb.instance.insertIfNew(txn(
          amount: 500,
          type: TxnType.debit,
          source: TxnSource.sms,
          time: at.add(const Duration(seconds: 20)),
          upiRef: '618239653510'));

      expect(id, isNull, reason: 'notification exposed no reference to match');

      final saved = (await TransactionsDb.instance.getAll()).single;
      expect(saved.upiRef, '618239653510',
          reason: 'the reference is backfilled onto the existing row');
    });
  });

  group('schema migration', () {
    // Column sets exactly as shipped, so an upgrade is tested against what
    // was actually on disk rather than against today's schema.
    const v1Columns = 'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'bank TEXT NOT NULL, amount REAL NOT NULL, type TEXT NOT NULL,'
        'timestampMillis INTEGER NOT NULL, rawSender TEXT NOT NULL,'
        'rawBody TEXT NOT NULL, category TEXT, reason TEXT';
    const v2Columns = 'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'bank TEXT NOT NULL, amount REAL NOT NULL, type TEXT NOT NULL,'
        'timestampMillis INTEGER NOT NULL,'
        "source TEXT NOT NULL DEFAULT 'sms', rawSender TEXT NOT NULL,"
        'rawBody TEXT NOT NULL, category TEXT, reason TEXT';

    Future<void> seedLegacy(int version, String columns) async {
      await TransactionsDb.instance.resetForTest();
      final path = p.join(await getDatabasesPath(), TransactionsDb.dbName);
      final legacy = await openDatabase(
        path,
        version: version,
        onCreate: (db, _) => db.execute('CREATE TABLE transactions ($columns)'),
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
      await TransactionsDb.instance.reopenForTest();
    }

    test('v1 upgrades without losing tagged rows', () async {
      await seedLegacy(1, v1Columns);

      final rows = await TransactionsDb.instance.getAll();
      expect(rows.length, 1);
      expect(rows.single.reason, 'gift');
      expect(rows.single.source, TxnSource.sms);
      expect(rows.single.upiRef, isNull);
    });

    test('v2 upgrades and can record a reference afterwards', () async {
      await seedLegacy(2, v2Columns);

      expect((await TransactionsDb.instance.getAll()).length, 1);

      final id = await TransactionsDb.instance.insertIfNew(txn(
          amount: 77,
          type: TxnType.debit,
          source: TxnSource.sms,
          time: at,
          upiRef: '618239653510'));
      expect(id, isNotNull, reason: 'new upiRef column must be writable');

      final saved = (await TransactionsDb.instance.getAll())
          .firstWhere((t) => t.amount == 77);
      expect(saved.upiRef, '618239653510');
    });

  });
}
