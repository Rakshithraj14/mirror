import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/transaction.dart';

class TransactionsDb {
  TransactionsDb._();
  static final TransactionsDb instance = TransactionsDb._();

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'yumeko.db'),
      version: 1,
      onCreate: (db, version) => db.execute('''
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
  }

  Future<int> insert(Txn txn) async {
    final db = await _database;
    final map = txn.toMap()..remove('id');
    return db.insert('transactions', map);
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

  Future<List<Txn>> getAll() async {
    final db = await _database;
    final rows = await db.query('transactions', orderBy: 'timestampMillis DESC');
    return rows.map(Txn.fromMap).toList();
  }
}
