import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/transaction.dart';
import 'package:penny/services/export_csv.dart';

Txn txn({
  required double amount,
  TxnType type = TxnType.debit,
  String? category,
  String? reason,
  String bank = 'Canara Bank',
  TxnSource source = TxnSource.sms,
  String? upiRef,
}) =>
    Txn(
      bank: bank,
      amount: amount,
      type: type,
      time: DateTime(2026, 3, 12, 14, 32, 5),
      source: source,
      rawSender: 'AD-CANBNK',
      rawBody: 'Acct XXX489 Dr. INR 190.00, whatever',
      upiRef: upiRef,
      category: category,
      reason: reason,
    );

List<String> rowsOf(String csv) =>
    csv.trim().split('\n').map((l) => l.trimRight()).toList();

void main() {
  test('writes a header and one row per transaction', () {
    final csv = rowsOf(toCsv([txn(amount: 10), txn(amount: 20)]));

    // Reason is first so Notion uses it as the database Title.
    expect(csv.first,
        'Reason,Date,Amount,Direction,Category,Bank,Source,UPI Ref');
    expect(csv.length, 3);
  });

  test('renders a tagged debit for Notion', () {
    final csv = rowsOf(toCsv([
      txn(
        amount: 190,
        category: 'family',
        reason: 'baby soap',
        upiRef: '618239653510',
      )
    ]));

    expect(
      csv[1],
      'baby soap,2026-03-12T14:32:05,190.00,Debit,Family,'
      'Canara Bank,sms,618239653510',
    );
  });

  test('leaves category and reason empty when untagged', () {
    // Notion's "is empty" filter is how you find these; the word "Untagged"
    // would look like a fourth category instead.
    final fields = rowsOf(toCsv([txn(amount: 40)]))[1].split(',');

    expect(fields[0], '', reason: 'the Title cell');
    expect(fields[4], '', reason: 'the Category cell');
  });

  test('credits are marked, and amounts stay unsigned', () {
    final fields =
        rowsOf(toCsv([txn(amount: 1000, type: TxnType.credit)]))[1].split(',');

    expect(fields[2], '1000.00');
    expect(fields[3], 'Credit');
  });

  test('escapes commas and quotes in a reason', () {
    // Reasons are free text. One unescaped comma would shift every later
    // column, silently corrupting the import.
    final csv = rowsOf(toCsv([
      txn(amount: 60, category: 'personal', reason: 'a "quoted", comma')
    ]));

    expect(csv[1], startsWith('"a ""quoted"", comma"'));
    expect(csv[1].split(',').last, '');
  });

  test('a newline in a reason cannot break the row apart', () {
    final csv = toCsv([
      txn(amount: 60, category: 'personal', reason: 'line1\nline2')
    ]);

    expect(csv, contains('"line1\nline2"'));
  });

  test('manual entries carry their own source', () {
    final fields = rowsOf(toCsv([
      txn(
        amount: 40,
        bank: 'Cash',
        source: TxnSource.manual,
        category: 'personal',
        reason: 'chai',
      )
    ]))[1]
        .split(',');

    expect(fields[5], 'Cash');
    expect(fields[6], 'manual');
  });
}
