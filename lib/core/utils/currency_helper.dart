import 'package:flutter/material.dart';

class CurrencyHelper {
  static String getSymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'PYG':
        return 'Gs';
      default:
        return currencyCode;
    }
  }

  static String format(num amount, String currencyCode) {
    final symbol = getSymbol(currencyCode);
    if (currencyCode.toUpperCase() == 'PYG') {
      // PYG usually doesn't use decimals in common displays
      return '$symbol ${amount.toStringAsFixed(0)}';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  static IconData getIcon(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return Icons.attach_money;
      case 'PYG':
        return Icons.payments_outlined;
      default:
        return Icons.money;
    }
  }
}
