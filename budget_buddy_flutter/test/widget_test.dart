import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_buddy_flutter/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const BudgetBuddyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Budget Buddy'), findsOneWidget);
  });
}