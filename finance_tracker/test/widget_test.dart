import 'package:flutter_test/flutter_test.dart';

import 'package:finance_tracker/main.dart';

void main() {
  testWidgets("App launches smoke test", (WidgetTester tester) async {
    await tester.pumpWidget(const FinanceTrackerApp());

    expect(find.text("Finance Tracker - Phase 1 Complete"), findsOneWidget);
  });
}
