import 'package:flutter/foundation.dart' hide Category;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';

/// Two sources (bank SMS and payment-app notification) can report the same
/// transaction seconds apart, so a same-amount/same-direction hit inside this
/// window is treated as one transaction.
const _dedupeWindow = Duration(minutes: 2);

class TransactionsDb {
  TransactionsDb._();
  static final TransactionsDb instance = TransactionsDb._();

  /// On-device tests point this at a throwaway file so they never touch (or
  /// delete) the real transaction history.
  @visibleForTesting
  static String dbName = 'yumeko.db';

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, dbName),
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bank TEXT NOT NULL,
            amount REAL NOT NULL,
            type TEXT NOT NULL,
            timestampMillis INTEGER NOT NULL,
            source TEXT NOT NULL DEFAULT 'sms',
            rawSender TEXT NOT NULL,
            rawBody TEXT NOT NULL,
            upiRef TEXT,
            category TEXT,
            reason TEXT,
            balanceAfter REAL
          )
        ''');
        // Settings.
        await db.execute(
            'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await _createCategories(db);
        await _createAccounts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE transactions ADD COLUMN source TEXT NOT NULL "
            "DEFAULT 'sms'",
          );
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE transactions ADD COLUMN upiRef TEXT');
          await db.execute(
              'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        }
        if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE transactions ADD COLUMN balanceAfter REAL');
        }
        if (oldVersion < 5) {
          // Categories and accounts stop being hard-coded. The three defaults
          // carry the same ids the old enum stored, so every transaction
          // already tagged keeps its category without touching a single row.
          await _createCategories(db);
          await _createAccounts(db);
          // Opening balances briefly lived in `meta`; bring them across.
          final legacy = await db.query('meta',
              where: 'key LIKE ?', whereArgs: ['opening:%']);
          for (final row in legacy) {
            final name = (row['key'] as String).substring('opening:'.length);
            await db.insert(
              'accounts',
              Account(
                name: name,
                kind: name == cashAccount ? AccountKind.cash : AccountKind.bank,
                opening: double.tryParse(row['value'] as String) ?? 0,
              ).toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await db.delete('meta', where: "key LIKE 'opening:%'");
        }
      },
    );
  }

  static Future<void> _createCategories(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        position INTEGER NOT NULL
      )
    ''');
    for (final category in Category.defaults) {
      await db.insert('categories', category.toMap());
    }
  }

  static Future<void> _createAccounts(Database db) async {
    await db.execute('''
      CREATE TABLE accounts (
        name TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        opening REAL NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.insert(
      'accounts',
      const Account(name: cashAccount, kind: AccountKind.cash).toMap(),
    );
  }

  Future<List<Category>> categories() async {
    final db = await _database;
    final rows = await db.query('categories', orderBy: 'position, label');
    return rows.map(Category.fromMap).toList();
  }

  Future<void> upsertCategory(Category category) async {
    final db = await _database;
    await db.insert('categories', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Removes a category and untags whatever was using it.
  ///
  /// Leaving the id behind would show a category that no longer exists, and a
  /// silent orphan is worse than an honest "needs tagging".
  Future<void> deleteCategory(String id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update('transactions', {'category': null, 'reason': null},
          where: 'category = ?', whereArgs: [id]);
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> countWithCategory(String id) async {
    final db = await _database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) c FROM transactions WHERE category = ?', [id]);
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<Account>> accounts() async {
    final db = await _database;
    final rows = await db.query('accounts', orderBy: 'position, name');
    return rows.map(Account.fromMap).toList();
  }

  Future<void> upsertAccount(Account account) async {
    final db = await _database;
    await db.insert('accounts', account.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAccount(String name) async {
    final db = await _database;
    await db.delete('accounts', where: 'name = ?', whereArgs: [name]);
  }

  Future<int> countWithAccount(String name) async {
    final db = await _database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) c FROM transactions WHERE bank = ?', [name]);
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Makes sure every bank that has actually sent something has a row, so a
  /// new bank shows up the first time it appears rather than being invisible
  /// until someone adds it by hand.
  Future<void> ensureAccountsForBanks() async {
    final db = await _database;
    final known = (await accounts()).map((a) => a.name).toSet();
    final seen = await db.rawQuery('SELECT DISTINCT bank FROM transactions');
    for (final row in seen) {
      final name = row['bank'] as String;
      if (known.contains(name)) continue;
      await db.insert(
        'accounts',
        Account(
          name: name,
          kind: name == cashAccount ? AccountKind.cash : AccountKind.bank,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Inserts [txn] unless it duplicates one already captured from the other
  /// source, returning the new row id or null when it was a duplicate.
  ///
  /// A bank SMS names the actual bank, while a notification only names the
  /// payment app, so an SMS arriving second upgrades the existing row instead
  /// of being dropped outright.
  Future<int?> insertIfNew(Txn txn) async {
    final db = await _database;
    final existing = await _findDuplicate(db, txn);

    if (existing != null) {
      if (txn.source == TxnSource.sms &&
          existing.source == TxnSource.notification) {
        await db.update(
          'transactions',
          {
            'bank': txn.bank,
            'source': txn.source.name,
            'rawSender': txn.rawSender,
            'rawBody': txn.rawBody,
            if (txn.upiRef != null) 'upiRef': txn.upiRef,
            if (txn.balanceAfter != null) 'balanceAfter': txn.balanceAfter,
          },
          where: 'id = ?',
          whereArgs: [existing.id],
        );
      } else if (existing.upiRef == null && txn.upiRef != null) {
        await db.update(
          'transactions',
          {'upiRef': txn.upiRef},
          where: 'id = ?',
          whereArgs: [existing.id],
        );
      }
      return null;
    }

    return insert(txn);
  }

  /// Inserts unconditionally, returning the new row id.
  ///
  /// Manually added transactions come through here rather than [insertIfNew]:
  /// a ₹50 cash entry that happened to land inside the dedupe window of a
  /// captured ₹50 would be swallowed, and an explicit user action that
  /// silently does nothing is a bug nobody can see.
  Future<int> insert(Txn txn) async {
    final db = await _database;
    return db.insert('transactions', txn.toMap()..remove('id'));
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Matches on the UPI reference when both sides carry one, and otherwise
  /// falls back to amount + direction inside a time window.
  ///
  /// The fallback still runs when the incoming reference finds nothing, since
  /// the earlier report (a notification, typically) may not have exposed one.
  /// But a row whose reference is known and *different* is a provably separate
  /// transaction, so two same-value payments minutes apart stay separate.
  Future<Txn?> _findDuplicate(Database db, Txn txn) async {
    if (txn.upiRef != null) {
      final byRef = await db.query(
        'transactions',
        where: 'upiRef = ?',
        whereArgs: [txn.upiRef],
        limit: 1,
      );
      if (byRef.isNotEmpty) return Txn.fromMap(byRef.first);
    }

    final millis = txn.time.millisecondsSinceEpoch;
    final rows = await db.query(
      'transactions',
      where: 'amount = ? AND type = ? AND timestampMillis BETWEEN ? AND ?'
          '${txn.upiRef != null ? ' AND upiRef IS NULL' : ''}',
      whereArgs: [
        txn.amount,
        txn.type.name,
        millis - _dedupeWindow.inMilliseconds,
        millis + _dedupeWindow.inMilliseconds,
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : Txn.fromMap(rows.first);
  }

  Future<void> tag(int id, String category, String reason) async {
    final db = await _database;
    await db.update(
      'transactions',
      {'category': category, 'reason': reason},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Drops and reopens the database against a clean file. Tests only.
  @visibleForTesting
  Future<void> resetForTest() async {
    await _db?.close();
    _db = null;
    final dbPath = p.join(await getDatabasesPath(), dbName);
    await deleteDatabase(dbPath);
  }

  /// Closes the handle so the next call reads from disk. Tests only.
  @visibleForTesting
  Future<void> reopenForTest() async {
    await _db?.close();
    _db = null;
  }

  Future<String?> meta(String key) async {
    final db = await _database;
    final rows =
        await db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<Map<String, String>> metaWithPrefix(String prefix) async {
    final db = await _database;
    final rows = await db.query('meta',
        where: 'key LIKE ?', whereArgs: ['$prefix%']);
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> setMeta(String key, String value) async {
    final db = await _database;
    await db.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMeta(String key) async {
    final db = await _database;
    await db.delete('meta', where: 'key = ?', whereArgs: [key]);
  }

  Future<List<Txn>> getAll() async {
    final db = await _database;
    final rows = await db.query('transactions', orderBy: 'timestampMillis DESC');
    return rows.map(Txn.fromMap).toList();
  }

  /// How the overlay finds the payment it was raised for. It runs in its own
  /// engine, so the database is the only thing both sides can see.
  Future<Txn?> byId(int id) async {
    final db = await _database;
    final rows =
        await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Txn.fromMap(rows.first);
  }
}
