import 'package:flutter_test/flutter_test.dart';

import 'package:penny/main.dart';

void main() {
  testWidgets('Home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const YumekoApp());

    expect(find.text('Yumeko'), findsOneWidget);
    expect(find.text('Enable transaction capture'), findsOneWidget);
  });
}
