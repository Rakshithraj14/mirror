// Design preview: the whole app against an in-memory store, with a theme
// toggle, so both palettes can be reviewed in a browser.
// Not part of the shipped app.
import 'dart:math';

import 'package:flutter/material.dart';

import 'models/account.dart';
import 'models/category.dart';
import 'models/transaction.dart';
import 'screens/home_shell.dart';
import 'services/txn_store.dart';
import 'theme.dart';

void main() => runApp(const _Preview());

/// Everything the database would do, in memory. Calling sqflite from a web
/// build throws MissingPluginException, which would make every add, tag and
/// balance edit in the preview silently do nothing.
class _PreviewStore extends TxnStore {
  final List<Txn> _txns = _sample();
  final List<Category> _categories = List.of(Category.defaults);
  final List<Account> _accounts = [
    const Account(name: cashAccount, kind: AccountKind.cash, opening: 2000),
    const Account(name: 'Canara Bank', kind: AccountKind.bank, opening: 24000),
    const Account(
        name: 'India Post Payments Bank',
        kind: AccountKind.bank,
        opening: 12000),
  ];
  var _nextId = 10000;

  @override
  Future<List<Txn>> load() async =>
      List.of(_txns)..sort((a, b) => b.time.compareTo(a.time));

  @override
  Future<void> add(Txn txn) async => _txns.add(_copy(txn, id: _nextId++));

  @override
  Future<void> tag(int id, String category, String reason) async {
    final i = _txns.indexWhere((t) => t.id == id);
    if (i >= 0) _txns[i] = _copy(_txns[i], category: category, reason: reason);
  }

  @override
  Future<void> delete(int id) async => _txns.removeWhere((t) => t.id == id);

  @override
  Future<List<Category>> categories() async => List.of(_categories);

  @override
  Future<void> saveCategory(Category category) async {
    final i = _categories.indexWhere((c) => c.id == category.id);
    i >= 0 ? _categories[i] = category : _categories.add(category);
  }

  @override
  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
    for (var i = 0; i < _txns.length; i++) {
      if (_txns[i].category == id) {
        _txns[i] = _copy(_txns[i], clearTag: true);
      }
    }
  }

  @override
  Future<int> countWithCategory(String id) async =>
      _txns.where((t) => t.category == id).length;

  @override
  Future<List<Account>> accounts() async {
    for (final bank in _txns.map((t) => t.bank).toSet()) {
      if (_accounts.any((a) => a.name == bank)) continue;
      _accounts.add(Account(
          name: bank,
          kind: bank == cashAccount ? AccountKind.cash : AccountKind.bank));
    }
    return List.of(_accounts);
  }

  @override
  Future<void> saveAccount(Account account) async {
    final i = _accounts.indexWhere((a) => a.name == account.name);
    i >= 0 ? _accounts[i] = account : _accounts.add(account);
  }

  @override
  Future<void> deleteAccount(String name) async =>
      _accounts.removeWhere((a) => a.name == name);

  @override
  Future<int> countWithAccount(String name) async =>
      _txns.where((t) => t.bank == name).length;

  Txn _copy(Txn t,
          {int? id, String? category, String? reason, bool clearTag = false}) =>
      Txn(
        id: id ?? t.id,
        bank: t.bank,
        amount: t.amount,
        type: t.type,
        time: t.time,
        source: t.source,
        rawSender: t.rawSender,
        rawBody: t.rawBody,
        upiRef: t.upiRef,
        balanceAfter: t.balanceAfter,
        category: clearTag ? null : (category ?? t.category),
        reason: clearTag ? null : (reason ?? t.reason),
      );
}

class _Preview extends StatefulWidget {
  const _Preview();

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  ThemeMode _mode = ThemeMode.dark;
  final _store = _PreviewStore();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: yumekoTheme(Brightness.light),
      darkTheme: yumekoTheme(Brightness.dark),
      themeMode: _mode,
      home: Builder(
        builder: (context) {
          final shell = HomeShell(
            store: _store,
            themeMode: _mode,
            onThemeChanged: (m) => setState(() => _mode = m),
            initialTab:
                int.tryParse(Uri.base.queryParameters['tab'] ?? '') ?? 0,
          );
          if (MediaQuery.sizeOf(context).width < 520) return shell;

          // On a desktop browser the app would stretch to the window width,
          // which is a layout nobody will ever see.
          return ColoredBox(
            color: const Color(0xFF141414),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: SizedBox(width: 400, height: 860, child: shell),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final mode in [ThemeMode.dark, ThemeMode.light])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FilledButton(
                            onPressed: () => setState(() => _mode = mode),
                            style: FilledButton.styleFrom(
                              backgroundColor: _mode == mode
                                  ? const Color(0xFFBC13FE)
                                  : const Color(0xFF2A2A2A),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(mode.name),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

List<Txn> _sample() {
  final now = DateTime.now();
  final rng = Random(7);
  const reasons = {
    'family': [
      'baby soap', 'nose drops', 'grocery', 'medicines', 'electricity bill',
    ],
    'personal': [
      'chai', 'auto', 'haircut', 'books', 'gym', 'fuel', 'online order',
    ],
    'office': ['team lunch', 'cab', 'domain renewal'],
  };
  const banks = ['Canara Bank', 'India Post Payments Bank', 'Cash'];

  final txns = <Txn>[];
  for (var day = 0; day < 30; day++) {
    for (var n = 0; n < 1 + rng.nextInt(3); n++) {
      final tagged = rng.nextInt(10) > 3;
      final category = reasons.keys.elementAt(rng.nextInt(reasons.length));
      const amounts = [5.0, 40, 70, 120, 190, 260, 585, 732, 1200];
      txns.add(Txn(
        id: txns.length + 1,
        bank: banks[rng.nextInt(banks.length)],
        amount: amounts[rng.nextInt(amounts.length)].toDouble(),
        type: TxnType.debit,
        time: now.subtract(Duration(days: day, hours: rng.nextInt(14))),
        source: TxnSource.sms,
        rawSender: 'AD-CANBNK',
        rawBody: 'raw',
        category: tagged ? category : null,
        reason: tagged
            ? reasons[category]![rng.nextInt(reasons[category]!.length)]
            : null,
      ));
    }
  }
  txns.add(Txn(
    id: 999,
    bank: 'Canara Bank',
    amount: 12450,
    type: TxnType.credit,
    time: now.subtract(const Duration(days: 4, hours: 3)),
    source: TxnSource.sms,
    rawSender: 'AD-CANBNK',
    rawBody: 'raw',
  ));
  txns.sort((a, b) => b.time.compareTo(a.time));
  return txns;
}
