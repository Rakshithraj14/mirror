import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
      version: 3,
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
            reason TEXT
          )
        ''');
        await db.execute(
            'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
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
      },
    );
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

    final map = txn.toMap()..remove('id');
    return db.insert('transactions', map);
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

  Future<bool> isBackfillDone() async {
    final db = await _database;
    final rows = await db.query('meta',
        where: 'key = ?', whereArgs: ['smsBackfillDone'], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> markBackfillDone() async {
    final db = await _database;
    await db.insert(
      'meta',
      {'key': 'smsBackfillDone', 'value': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> tag(int id, TxnCategory category, String reason) async {
    final db = await _database;
    await db.update(
      'transactions',
      {'category': category.name, 'reason': reason},
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

  Future<List<Txn>> getAll() async {
    final db = await _database;
    final rows = await db.query('transactions', orderBy: 'timestampMillis DESC');
    return rows.map(Txn.fromMap).toList();
  }
}
