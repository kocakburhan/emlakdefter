import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EmlakdefterApp()));
    await tester.pumpAndSettle();

    // Verify that role selection screen appears
    expect(find.text('Emlakdefter.'), findsOneWidget);
  });
}