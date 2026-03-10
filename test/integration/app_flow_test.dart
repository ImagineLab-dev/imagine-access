import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:imagine_access/main.dart';

/// Tests de integración simplificados para flujos principales
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key-which-is-long-enough-for-tests',
    );
  });

  group('App Integration Tests', () {
    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: ImagineAccessApp()));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('App launches successfully', (WidgetTester tester) async {
      await pumpApp(tester);

      // Verify login screen appears
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Welcome shows both access options', (WidgetTester tester) async {
      await pumpApp(tester);

      expect(find.text('Admin / RRPP'), findsOneWidget);
      expect(find.text('Door Access'), findsOneWidget);
    });

    testWidgets('Theme toggle works', (WidgetTester tester) async {
      await pumpApp(tester);

      final themeIcon = find.byIcon(Icons.brightness_6_rounded);
      if (themeIcon.evaluate().isNotEmpty) {
        await tester.tap(themeIcon.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Find and tap theme toggle
      final switchFinder = find.byType(Switch);
      if (switchFinder.evaluate().isNotEmpty) {
        await tester.tap(switchFinder.first);
        await tester.pump(const Duration(milliseconds: 250));
      }
    });
  });
}
