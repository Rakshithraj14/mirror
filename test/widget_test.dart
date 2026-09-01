import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:penny/main.dart';
import 'package:penny/services/transactions_db.dart';
import 'package:penny/theme.dart';
import 'package:penny/widgets/nav_bar.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Test files run concurrently and would otherwise share one database file.
    TransactionsDb.dbName = 'yumeko_widget_test.db';
  });

  setUp(() async => TransactionsDb.instance.resetForTest());

  /// runAsync so the real sqflite query can complete — inside the default
  /// fake-async zone the FutureBuilder would never resolve.
  Future<void> pumpApp(WidgetTester tester,
      {ThemeMode mode = ThemeMode.dark}) async {
    // The cards fill the default 600px test surface on their own, so a lazy
    // ListView would never build the transaction list underneath them.
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(YumekoApp(initialThemeMode: mode));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  /// Real I/O has to settle inside runAsync — the fake-async zone never
  /// completes a sqflite future.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('Overview renders the spend card and the empty state',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('YUMEKO'), findsOneWidget);
    expect(find.text('Total spent'), findsOneWidget);
    expect(find.text('Your balances'), findsOneWidget);
    expect(find.textContaining('payments land here'), findsOneWidget);
  });

  testWidgets('every tab is reachable from the nav bar', (tester) async {
    await pumpApp(tester);

    for (final entry in {1: 'Transactions', 2: 'Insights', 3: 'Profile'}.entries) {
      await tester.tap(find.byIcon(navItems[entry.key].icon));
      await tester.pumpAndSettle();
      // Once as the nav label, once as the screen heading.
      expect(find.text(entry.value), findsNWidgets(2));
    }
  });

  testWidgets('the add button opens the sheet from any tab', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(navItems[2].icon));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Add payment'), findsOneWidget);
    expect(find.text('What was it for?'), findsOneWidget);
  });

  testWidgets('the add sheet refuses to save without an amount',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add payment'));
    await tester.pump();

    expect(find.text('Enter an amount'), findsOneWidget);
    // Still open, so nothing was silently written.
    expect(find.text('Add payment'), findsOneWidget);
  });

  testWidgets('the add sheet asks for a category before saving',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '40');
    await tester.tap(find.text('Add payment'));
    await tester.pump();

    expect(find.text('Pick a category'), findsOneWidget);
  });

  testWidgets('a manual payment lands with the tag read from its reason',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '40');
    await tester.tap(find.text('Personal'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'chai');
    await tester.tap(find.text('Add payment'));
    await settle(tester);

    expect(find.text('chai'), findsOneWidget);
    // "chai" is read as Cafe, so the row says so rather than repeating the
    // category you picked.
    expect(find.text('Cafe · Cash'), findsOneWidget);
  });

  // Two tests rather than one: YumekoApp reads initialThemeMode once, so
  // re-pumping the same widget keeps the mode it already has — which is right
  // for the app and useless for asserting the other theme.
  testWidgets('the light theme uses lime as a fill, never as ink',
      (tester) async {
    await pumpApp(tester, mode: ThemeMode.light);
    final p = Palette.of(tester.element(find.text('YUMEKO')));

    expect(p.accent, Palette.light.accent);
    // Lime is 1.32:1 on white, so it must never be the ink colour.
    expect(p.accentInk, isNot(p.accent));
  });

  testWidgets('the dark theme carries the purple accent', (tester) async {
    await pumpApp(tester);
    final p = Palette.of(tester.element(find.text('YUMEKO')));

    expect(p.accent, Palette.dark.accent);
    expect(p.ground, Palette.dark.ground);
  });
}
