import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker_app/main.dart';

void main() {
  testWidgets('expense dashboard supports create edit and delete actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ExpenseTrackerApp());

    expect(find.text('ExpenseTrackerApp'), findsOneWidget);
    expect(find.text('Hello Baby , This is for you'), findsOneWidget);
    expect(find.text('Slide up for expense process'), findsOneWidget);
    expect(find.text('View expense process'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, -760));
    await tester.pumpAndSettle();

    expect(find.text('Current expense process'), findsOneWidget);
    expect(find.text('Total spent'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Category breakdown'), findsOneWidget);
    expect(find.text('Recent expenses'), findsOneWidget);
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Coffee');
    await tester.enterText(find.byType(TextField).at(1), '45');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('\$45'), findsOneWidget);
    expect(find.text('Coffee created successfully'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
