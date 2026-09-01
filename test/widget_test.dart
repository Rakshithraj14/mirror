import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:penny/main.dart';
import 'package:penny/services/transactions_db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Test files run concurrently and would otherwise share one database file.
    TransactionsDb.dbName = 'yumeko_widget_test.db';
  });

  setUp(() async => TransactionsDb.instance.resetForTest());

  testWidgets('Dashboard renders the spend summary', (tester) async {
    // runAsync so the real sqflite query can complete — inside the default
    // fake-async zone the FutureBuilder would never resolve.
    await tester.runAsync(() async {
      await tester.pumpWidget(const YumekoApp());
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('Yumeko'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Transactions · 0'), findsOneWidget);
    expect(find.text('Nothing captured yet.'), findsOneWidget);
  });
}
