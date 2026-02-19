// Basic smoke test for Lego Brick Counter app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lego_brick_counter_app/main.dart';

void main() {
  testWidgets('App renders auth gate on start', (WidgetTester tester) async {
    await tester.pumpWidget(const LegoApp());

    // The app should show the login page by default
    expect(find.text('Login'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
  });
}
