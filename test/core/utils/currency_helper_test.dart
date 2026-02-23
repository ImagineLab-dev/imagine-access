import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:imagine_access/core/utils/currency_helper.dart';

void main() {
  group('CurrencyHelper', () {
    group('format', () {
      test('should format PYG without decimals', () {
        final result = CurrencyHelper.format(150000.0, 'PYG');
        expect(result, 'Gs 150000');
      });

      test('should format USD with 2 decimals', () {
        final result = CurrencyHelper.format(99.99, 'USD');
        expect(result, '\$99.99');
      });

      test('should format default currency correctly', () {
        final result = CurrencyHelper.format(1000.0, 'XYZ');
        expect(result, 'XYZ1000.00');
      });

      test('should handle zero correctly', () {
        final result = CurrencyHelper.format(0.0, 'USD');
        expect(result, '\$0.00');
      });

      test('should handle negative numbers', () {
        final result = CurrencyHelper.format(-50.0, 'USD');
        expect(result, '\$-50.00');
      });
    });

    group('getIcon', () {
      test('should return attach_money for USD', () {
        expect(CurrencyHelper.getIcon('USD'), equals(Icons.attach_money));
      });

      test('should return payments_outlined for PYG', () {
        expect(CurrencyHelper.getIcon('PYG'), equals(Icons.payments_outlined));
      });

      test('should return money for unknown currency', () {
        expect(CurrencyHelper.getIcon('XYZ'), equals(Icons.money));
      });
    });

    group('getSymbol', () {
      test('should return \$ for USD', () {
        expect(CurrencyHelper.getSymbol('USD'), equals('\$'));
      });

      test('should return Gs for PYG', () {
        expect(CurrencyHelper.getSymbol('PYG'), equals('Gs'));
      });

      test('should return currency code for unknown currency', () {
        expect(CurrencyHelper.getSymbol('XYZ'), equals('XYZ'));
      });

      test('should handle uppercase conversion', () {
        expect(CurrencyHelper.getSymbol('usd'), equals('\$'));
        expect(CurrencyHelper.getSymbol('pyg'), equals('Gs'));
      });
    });
  });
}
