import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/account.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/profile.dart';
import 'package:penny/models/transaction.dart';
import 'package:penny/services/capture.dart';
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

  test('a manual insert is never treated as a duplicate', () async {
    // Adding a payment by hand is an explicit request. Routing it through the
    // dedupe window would let a cash entry vanish because a captured one
    // happened to share its amount, with nothing on screen to say so.
    final captured = txn(
        amount: 50, type: TxnType.debit, source: TxnSource.sms, time: at);
    await TransactionsDb.instance.insertIfNew(captured);

    await TransactionsDb.instance.insert(txn(
        amount: 50,
        type: TxnType.debit,
        source: TxnSource.manual,
        time: at,
        bank: 'Cash'));

    expect((await TransactionsDb.instance.getAll()).length, 2);
  });

  test('delete removes only the row asked for', () async {
    final keep = await TransactionsDb.instance.insert(
        txn(amount: 10, type: TxnType.debit, source: TxnSource.manual, time: at));
    final drop = await TransactionsDb.instance.insert(
        txn(amount: 20, type: TxnType.debit, source: TxnSource.manual, time: at));

    await TransactionsDb.instance.delete(drop);

    final left = await TransactionsDb.instance.getAll();
    expect(left.map((t) => t.id), [keep]);
  });

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
    await TransactionsDb.instance.tag(id!, 'office', 'team lunch');

    final saved = (await TransactionsDb.instance.getAll()).single;
    expect(saved.isTagged, isTrue);
    expect(saved.category, 'office');
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

  group('categories', () {
    test('ships with the three defaults, keyed as the old enum was', () async {
      final categories = await TransactionsDb.instance.categories();
      expect(categories.map((c) => c.id), ['personal', 'family', 'office']);
    });

    test('a new category can be added and used', () async {
      await TransactionsDb.instance.upsertCategory(
          const Category(id: 'travel', label: 'Travel', position: 3));
      final id = await TransactionsDb.instance.insert(txn(
          amount: 900,
          type: TxnType.debit,
          source: TxnSource.manual,
          time: at));
      await TransactionsDb.instance.tag(id, 'travel', 'flight');

      expect(await TransactionsDb.instance.countWithCategory('travel'), 1);
    });

    test('deleting a category untags its payments instead of orphaning them',
        () async {
      final id = await TransactionsDb.instance.insert(txn(
          amount: 120,
          type: TxnType.debit,
          source: TxnSource.manual,
          time: at));
      await TransactionsDb.instance.tag(id, 'office', 'team lunch');

      await TransactionsDb.instance.deleteCategory('office');

      final saved = (await TransactionsDb.instance.getAll()).single;
      expect(saved.amount, 120, reason: 'the payment itself survives');
      expect(saved.category, isNull);
      expect(saved.isTagged, isFalse);
      expect((await TransactionsDb.instance.categories()).map((c) => c.id),
          isNot(contains('office')));
    });

    test('renaming keeps the id, so tagged payments follow the new name',
        () async {
      final id = await TransactionsDb.instance.insert(txn(
          amount: 60,
          type: TxnType.debit,
          source: TxnSource.manual,
          time: at));
      await TransactionsDb.instance.tag(id, 'personal', 'chai');

      await TransactionsDb.instance.upsertCategory(
          const Category(id: 'personal', label: 'Me', position: 0));

      expect(await TransactionsDb.instance.countWithCategory('personal'), 1);
      final renamed = (await TransactionsDb.instance.categories())
          .firstWhere((c) => c.id == 'personal');
      expect(renamed.label, 'Me');
    });
  });

  group('accounts', () {
    test('Cash exists from the start', () async {
      final accounts = await TransactionsDb.instance.accounts();
      expect(accounts.single.name, cashAccount);
      expect(accounts.single.kind, AccountKind.cash);
    });

    test('a bank appears the first time it sends something', () async {
      await TransactionsDb.instance.insert(txn(
          amount: 10,
          type: TxnType.debit,
          source: TxnSource.sms,
          time: at,
          bank: 'HDFC Bank'));
      await TransactionsDb.instance.ensureAccountsForBanks();

      final names =
          (await TransactionsDb.instance.accounts()).map((a) => a.name);
      expect(names, containsAll([cashAccount, 'HDFC Bank']));
    });

    test('an opening balance survives a round trip', () async {
      await TransactionsDb.instance.upsertAccount(const Account(
          name: 'Canara Bank', kind: AccountKind.bank, opening: 2500));

      final saved = (await TransactionsDb.instance.accounts())
          .firstWhere((a) => a.name == 'Canara Bank');
      expect(saved.opening, 2500);
      expect(saved.kind, AccountKind.bank);
    });

    test('an account in use is counted before it can be removed', () async {
      await TransactionsDb.instance.insert(txn(
          amount: 10,
          type: TxnType.debit,
          source: TxnSource.manual,
          time: at,
          bank: cashAccount));

      expect(await TransactionsDb.instance.countWithAccount(cashAccount), 1);
      expect(await TransactionsDb.instance.countWithAccount('Nowhere'), 0);
    });
  });

  group('profile', () {
    test('a fresh database already answers to Yumeko', () async {
      final profile = await TransactionsDb.instance.profile();
      expect(profile.name, 'Yumeko');
      expect(profile.avatar, isNull);
    });

    test('name and photo round-trip', () async {
      await TransactionsDb.instance.saveProfile(
          const Profile(name: '  Rakshith  ', avatar: '/data/avatar_1.jpg'));

      final saved = await TransactionsDb.instance.profile();
      expect(saved.name, 'Rakshith', reason: 'stored trimmed');
      expect(saved.avatar, '/data/avatar_1.jpg');
    });

    test('removing the photo clears the row rather than storing a blank',
        () async {
      await TransactionsDb.instance
          .saveProfile(const Profile(name: 'R', avatar: '/data/avatar_1.jpg'));
      await TransactionsDb.instance.saveProfile(const Profile(name: 'R'));

      // Stored empty, `profile()` would read back a path pointing nowhere and
      // the card would try to decode it.
      expect(await TransactionsDb.instance.meta('profile:avatar'), isNull);
      expect((await TransactionsDb.instance.profile()).hasAvatar, isFalse);
    });
  });

  group('the overlay handover', () {
    // The overlay runs in a second engine, so the row and the id it was raised
    // for both travel through the database rather than a timed message.
    test('byId returns the row the popup was raised for', () async {
      final id = await TransactionsDb.instance.insert(
          txn(amount: 190, type: TxnType.debit, source: TxnSource.sms, time: at));

      final found = await TransactionsDb.instance.byId(id);
      expect(found?.amount, 190);
      expect(found?.id, id);
    });

    test('byId is null for a row that is gone', () async {
      // The overlay closes itself on this rather than showing an empty card
      // that cannot be dismissed.
      expect(await TransactionsDb.instance.byId(4242), isNull);
    });

    test('the pending id round-trips and clears', () async {
      await TransactionsDb.instance.setMeta(pendingKey, '7');
      expect(await TransactionsDb.instance.meta(pendingKey), '7');

      await TransactionsDb.instance.deleteMeta(pendingKey);
      expect(await TransactionsDb.instance.meta(pendingKey), isNull);
    });
  });
}
