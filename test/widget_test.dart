import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journey_guard_ai/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JourneyGuardApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
