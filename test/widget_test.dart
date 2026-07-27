import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roshni_rams/main.dart';

void main() {
  testWidgets('App loads and displays login screen', (WidgetTester tester) async {
    // Set standard landscape screen size to prevent overflow warnings
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: RAMSApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that the login screen elements are displayed
    expect(find.text('Login'), findsWidgets);

    // Reset screen size
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
