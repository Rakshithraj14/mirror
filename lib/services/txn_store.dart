import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import 'transactions_db.dart';

/// Every read and write the app makes, in one place.
///
/// The database is the real implementation; the design preview subclasses this
/// with in-memory state so the browser build can actually add, tag and delete
/// rows. Calling sqflite from a web build throws MissingPluginException, which
/// used to make the preview silently drop every edit.
class TxnStore {
  const TxnStore();

  Future<List<Txn>> load() => TransactionsDb.instance.getAll();

  Future<void> add(Txn txn) => TransactionsDb.instance.insert(txn);

  Future<void> tag(int id, String category, String reason) =>
      TransactionsDb.instance.tag(id, category, reason);

  Future<void> delete(int id) => TransactionsDb.instance.delete(id);

  Future<List<Category>> categories() => TransactionsDb.instance.categories();

  Future<void> saveCategory(Category category) =>
      TransactionsDb.instance.upsertCategory(category);

  Future<void> deleteCategory(String id) =>
      TransactionsDb.instance.deleteCategory(id);

  Future<int> countWithCategory(String id) =>
      TransactionsDb.instance.countWithCategory(id);

  Future<List<Account>> accounts() async {
    await TransactionsDb.instance.ensureAccountsForBanks();
    return TransactionsDb.instance.accounts();
  }

  Future<void> saveAccount(Account account) =>
      TransactionsDb.instance.upsertAccount(account);

  Future<void> deleteAccount(String name) =>
      TransactionsDb.instance.deleteAccount(name);

  Future<int> countWithAccount(String name) =>
      TransactionsDb.instance.countWithAccount(name);
}
