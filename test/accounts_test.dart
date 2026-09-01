import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/account.dart';
import 'package:penny/models/transaction.dart';
import 'package:penny/services/accounts.dart';

Txn txn({
  required double amount,
  required TxnType type,
  required DateTime time,
  String bank = 'Canara Bank',
  double? balanceAfter,
}) =>
    Txn(
      bank: bank,
      amount: amount,
      type: type,
      time: time,
      source: TxnSource.sms,
      rawSender: 'AD-CANBNK',
      rawBody: 'raw',
      balanceAfter: balanceAfter,
    );

Account bank(String name, {double opening = 0}) =>
    Account(name: name, kind: AccountKind.bank, opening: opening);

Account cash({double opening = 0}) =>
    Account(name: cashAccount, kind: AccountKind.cash, opening: opening);

AccountBalance find(List<AccountBalance> all, String name) =>
    all.firstWhere((a) => a.account.name == name);

void main() {
  final at = DateTime(2026, 9, 1, 12);

  test('opening balance is adjusted by every transaction', () {
    final balances = accountBalances([
      txn(amount: 200, type: TxnType.debit, time: at),
      txn(amount: 50, type: TxnType.credit, time: at),
    ], [
      bank('Canara Bank', opening: 1000)
    ]);

    expect(find(balances, 'Canara Bank').balance, 850);
    expect(find(balances, 'Canara Bank').fromBank, isFalse);
  });

  test('an account with no opening figure still totals its own movements', () {
    final balances = accountBalances(
      [txn(amount: 200, type: TxnType.credit, time: at)],
      [bank('Canara Bank')],
    );
    expect(find(balances, 'Canara Bank').balance, 200);
  });

  test("the bank's own printed balance overrides the running total", () {
    // The whole point of the reconciliation: an opening figure that is wrong,
    // or a payment that was never captured, would otherwise drift forever.
    final balances = accountBalances([
      txn(amount: 500, type: TxnType.debit, time: at, balanceAfter: 98.75),
    ], [
      bank('Canara Bank', opening: 99999)
    ]);

    final canara = find(balances, 'Canara Bank');
    expect(canara.balance, 98.75);
    expect(canara.fromBank, isTrue);
  });

  test('only movements after the bank spoke are applied on top', () {
    final balances = accountBalances([
      txn(amount: 500, type: TxnType.debit, time: at, balanceAfter: 1000),
      txn(
          amount: 200,
          type: TxnType.debit,
          time: at.add(const Duration(hours: 1))),
      // Older than the anchor, so already reflected in the bank's figure.
      txn(
          amount: 900,
          type: TxnType.debit,
          time: at.subtract(const Duration(hours: 5))),
    ], [
      bank('Canara Bank')
    ]);

    expect(find(balances, 'Canara Bank').balance, 800);
  });

  test('the newest bank figure wins when there are several', () {
    final balances = accountBalances([
      txn(amount: 10, type: TxnType.debit, time: at, balanceAfter: 5000),
      txn(
          amount: 10,
          type: TxnType.debit,
          time: at.add(const Duration(days: 1)),
          balanceAfter: 300),
    ], [
      bank('Canara Bank')
    ]);

    expect(find(balances, 'Canara Bank').balance, 300);
  });

  test('cash is held at zero rather than going negative', () {
    // Physical cash cannot be negative. Showing -₹5,632 would be arithmetic
    // presented as fact; the flag is how the UI says something is missing.
    final balances = accountBalances([
      txn(amount: 800, type: TxnType.debit, time: at, bank: cashAccount),
    ], [
      cash(opening: 500)
    ]);

    final wallet = find(balances, cashAccount);
    expect(wallet.balance, 0);
    expect(wallet.clamped, isTrue);
  });

  test('a bank account is still allowed to go negative', () {
    // An overdrawn bank account is a real state, unlike a negative wallet.
    final balances = accountBalances([
      txn(amount: 800, type: TxnType.debit, time: at),
    ], [
      bank('Canara Bank', opening: 500)
    ]);

    expect(find(balances, 'Canara Bank').balance, -300);
    expect(find(balances, 'Canara Bank').clamped, isFalse);
  });

  test('accounts are kept apart', () {
    final balances = accountBalances([
      txn(amount: 100, type: TxnType.debit, time: at, bank: 'Canara Bank'),
      txn(amount: 40, type: TxnType.debit, time: at, bank: cashAccount),
    ], [
      bank('Canara Bank', opening: 1000),
      cash(opening: 500),
    ]);

    expect(find(balances, 'Canara Bank').balance, 900);
    expect(find(balances, cashAccount).balance, 460);
    expect(totalBalance(balances), 1360);
  });
}
