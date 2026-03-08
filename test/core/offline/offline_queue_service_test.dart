import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imagine_access/core/offline/offline_queue_service.dart';
import 'package:imagine_access/core/offline/pending_operation.dart';

void main() {
  group('OfflineQueueService', () {
    late OfflineQueueService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = OfflineQueueService();
    });

    test('enqueue persists operations', () async {
      final op = PendingOperation(
        id: 'op-1',
        type: 'create_ticket',
        payload: {'foo': 'bar'},
        createdAt: DateTime.now(),
      );

      await service.enqueue(op);
      final stored = await service.getPendingOperations();

      expect(stored, hasLength(1));
      expect(stored.first.id, equals('op-1'));
      expect(stored.first.type, equals('create_ticket'));
    });

    test('processQueue removes successful operations', () async {
      await service.enqueue(PendingOperation(
        id: 'op-2',
        type: 'create_ticket',
        payload: {'x': 1},
        createdAt: DateTime.now(),
      ));

      final result = await service.processQueue(
        executor: (_) async => true,
      );

      expect(result.processed, equals(1));
      expect(result.succeeded, equals(1));
      expect(result.remaining, equals(0));
      expect(await service.count(), equals(0));
    });

    test('processQueue retries failed operations', () async {
      await service.enqueue(PendingOperation(
        id: 'op-3',
        type: 'validate_ticket',
        payload: {'y': 2},
        createdAt: DateTime.now(),
      ));

      final result = await service.processQueue(
        executor: (_) async => false,
      );

      expect(result.processed, equals(1));
      expect(result.failed, equals(1));
      expect(result.remaining, equals(1));

      final pending = await service.getPendingOperations();
      expect(pending.first.retryCount, equals(1));
    });
  });
}
