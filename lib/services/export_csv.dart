import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/category.dart';
import '../models/transaction.dart';

const _headers = [
  'Reason',
  'Date',
  'Amount',
  'Direction',
  'Category',
  'Bank',
  'Source',
  'UPI Ref',
];

/// One row's worth of cells, shared by both export formats so the CSV and the
/// spreadsheet can never disagree about what a transaction was.
List<String> _row(Txn txn, List<Category> categories) => [
      txn.reason ?? '',
      // Seconds precision, local time: Notion parses this into a real Date.
      txn.time.toIso8601String().split('.').first,
      txn.amount.toStringAsFixed(2),
      txn.type == TxnType.credit ? 'Credit' : 'Debit',
      txn.category == null ? '' : categoryLabel(txn.category, categories),
      txn.bank,
      txn.source.name,
      txn.upiRef ?? '',
    ];

/// Every transaction as CSV, ready for Notion's database import.
///
/// Reason leads because Notion turns a CSV's first column into the database
/// Title. Anything else and every page would be named after its timestamp.
///
/// Amounts are unsigned with direction in its own column: a Notion rollup has
/// no abs(), so signed amounts would make "total spent" impossible to sum.
/// Untagged rows leave Category and Reason empty rather than writing
/// "Untagged", so Notion's *is empty* filter finds them.
///
/// The raw SMS body is deliberately left out — noisy in a table, and it
/// carries account fragments for no analytical benefit.
String toCsv(List<Txn> txns, {List<Category> categories = const []}) {
  final rows = StringBuffer()..writeln(_headers.join(','));
  for (final txn in txns) {
    rows.writeln(_row(txn, categories).map(_escape).join(','));
  }
  return rows.toString();
}

/// RFC 4180. Reasons are free text, so this is load-bearing rather than
/// defensive: one comma in "chai, samosa" would shift every later column.
String _escape(String field) {
  if (!field.contains(RegExp(r'[",\r\n]'))) return field;
  return '"${field.replaceAll('"', '""')}"';
}

/// The same rows as a real .xlsx, with the amount as a number rather than
/// text so Excel can sum a column without anyone reformatting it first.
List<int> toXlsx(List<Txn> txns, {List<Category> categories = const []}) {
  final book = xl.Excel.createExcel();
  final sheet = book[book.getDefaultSheet()!];

  sheet.appendRow([for (final h in _headers) xl.TextCellValue(h)]);
  for (final txn in txns) {
    final cells = _row(txn, categories);
    sheet.appendRow([
      xl.TextCellValue(cells[0]),
      xl.TextCellValue(cells[1]),
      xl.DoubleCellValue(txn.amount),
      xl.TextCellValue(cells[3]),
      xl.TextCellValue(cells[4]),
      xl.TextCellValue(cells[5]),
      xl.TextCellValue(cells[6]),
      xl.TextCellValue(cells[7]),
    ]);
  }
  return book.save() ?? const [];
}

enum ExportFormat { csv, xlsx }

/// Writes the export to a temporary file and hands it to the share sheet.
Future<void> exportTransactions(
  List<Txn> txns, {
  required ExportFormat format,
  List<Category> categories = const [],
}) async {
  final now = DateTime.now();
  final stamp = '${now.year}-${_two(now.month)}-${_two(now.day)}';
  final dir = await getTemporaryDirectory();

  final File file;
  final String mime;
  if (format == ExportFormat.csv) {
    file = File(p.join(dir.path, 'yumeko-$stamp.csv'));
    await file.writeAsString(toCsv(txns, categories: categories));
    mime = 'text/csv';
  } else {
    file = File(p.join(dir.path, 'yumeko-$stamp.xlsx'));
    await file.writeAsBytes(toXlsx(txns, categories: categories));
    mime =
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }

  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: mime)],
    subject: 'Yumeko transactions',
  ));
}

String _two(int n) => n.toString().padLeft(2, '0');
