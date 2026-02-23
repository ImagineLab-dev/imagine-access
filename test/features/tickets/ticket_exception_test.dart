import 'package:flutter_test/flutter_test.dart';
import 'package:imagine_access/features/tickets/data/ticket_repository.dart';

void main() {
  group('TicketException', () {
    test('should store message correctly', () {
      final exception = TicketException('Test error');
      expect(exception.message, equals('Test error'));
    });

    test('toString should return the message', () {
      final exception = TicketException('Error al crear ticket');
      expect(exception.toString(), equals('Error al crear ticket'));
    });

    test('should implement Exception', () {
      final exception = TicketException('test');
      expect(exception, isA<Exception>());
    });

    test('should handle empty message', () {
      final exception = TicketException('');
      expect(exception.message, equals(''));
      expect(exception.toString(), equals(''));
    });

    test('should handle special characters in message', () {
      final exception = TicketException('Error: ticket #123 (ñ, é)');
      expect(exception.toString(), equals('Error: ticket #123 (ñ, é)'));
    });
  });
}
