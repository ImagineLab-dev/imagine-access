import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:imagine_access/core/utils/error_handler.dart';

void main() {
  group('ErrorHandler.analyzeError', () {
    test('classifies socket exceptions as noConnection', () {
      final result = ErrorHandler.analyzeError(
        const SocketException('Failed host lookup'),
      );

      expect(result.type, equals(NetworkErrorType.noConnection));
      expect(result.isRetryable, isTrue);
    });

    test('classifies unauthorized errors', () {
      final result = ErrorHandler.analyzeError('401 Unauthorized');

      expect(result.type, equals(NetworkErrorType.unauthorized));
      expect(result.statusCode, equals(401));
      expect(result.isRetryable, isFalse);
    });

    test('classifies server errors as retryable', () {
      final result = ErrorHandler.analyzeError('503 server error');

      expect(result.type, equals(NetworkErrorType.serverError));
      expect(result.isRetryable, isTrue);
    });

    test('classifies unknown errors safely', () {
      final result = ErrorHandler.analyzeError(Exception('random failure'));

      expect(result.type, equals(NetworkErrorType.unknown));
      expect(result.message, isNotEmpty);
    });
  });
}
