import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imagine_access/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('darkTheme should return ThemeData with brightness.dark', () {
      final theme = AppTheme.darkTheme();
      expect(theme.brightness, equals(Brightness.dark));
    });

    test('lightTheme should return ThemeData with brightness.light', () {
      final theme = AppTheme.lightTheme();
      expect(theme.brightness, equals(Brightness.light));
    });

    test('darkTheme should use Material3', () {
      final theme = AppTheme.darkTheme();
      expect(theme.useMaterial3, isTrue);
    });

    test('lightTheme should use Material3', () {
      final theme = AppTheme.lightTheme();
      expect(theme.useMaterial3, isTrue);
    });

    test('Color constants should be defined', () {
      expect(AppTheme.darkBg, isA<Color>());
      expect(AppTheme.darkCard, isA<Color>());
      expect(AppTheme.lightBg, isA<Color>());
      expect(AppTheme.lightCard, isA<Color>());
      expect(AppTheme.accentBlue, isA<Color>());
      expect(AppTheme.accentGreen, isA<Color>());
    });

    test('primaryColor should be accentBlue', () {
      expect(AppTheme.primaryColor, equals(AppTheme.accentBlue));
    });
  });
}
