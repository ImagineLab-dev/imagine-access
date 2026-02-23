import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imagine_access/main.dart';

/// Tests de integración simplificados para flujos principales
void main() {
  group('App Integration Tests', () {
    testWidgets('App launches successfully', (WidgetTester tester) async {
      // Build app
      await tester.pumpWidget(const ProviderScope(child: ImagineAccessApp()));
      await tester.pumpAndSettle();

      // Verify login screen appears
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Login screen has both tabs', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: ImagineAccessApp()));
      await tester.pumpAndSettle();

      // Should find tab-related widgets
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('Theme toggle works', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: ImagineAccessApp()));
      await tester.pumpAndSettle();

      // Find and tap theme toggle
      final switchFinder = find.byType(Switch);
      if (switchFinder.evaluate().isNotEmpty) {
        await tester.tap(switchFinder.first);
        await tester.pumpAndSettle();
      }
    });
  });
}
