// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter_test/flutter_test.dart';
import 'package:kiu_students_app/main.dart';
import 'package:kiu_students_app/providers/theme_provider.dart';

void main() {
  testWidgets('App starts and shows login screen', (WidgetTester tester) async {
    // Create theme provider for test
    final themeProvider = ThemeProvider();

    // Build our app and trigger a frame.
    await tester.pumpWidget(KIUStudentsApp(themeProvider: themeProvider));

    // Wait for images to load
    await tester.pumpAndSettle();

    // Verify login screen is displayed
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
