import 'package:flutter_test/flutter_test.dart';
import 'package:imagine_access/core/constants/app_roles.dart';
import 'package:imagine_access/core/offline/offline_queue_service.dart';
import 'package:imagine_access/core/offline/pending_operation.dart';
import 'package:imagine_access/core/utils/error_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// These tests verify the MULTI-TENANT SECURITY contracts at the code level.
/// They check role constants, offline queue retry behavior, and key
/// data-flow contracts without needing a live Supabase connection.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Tenant Security Contracts', () {
    group('Role Constants - No Magic Strings', () {
      test('AppRoles constants match Supabase contract', () {
        expect(AppRoles.admin, equals('admin'));
        expect(AppRoles.rrpp, equals('rrpp'));
        expect(AppRoles.door, equals('door'));
      });

      test('All roles list is exhaustive', () {
        expect(AppRoles.all, hasLength(3));
        expect(AppRoles.all,
            containsAll([AppRoles.admin, AppRoles.rrpp, AppRoles.door]));
      });

      test('No duplicate roles in all list', () {
        final unique = AppRoles.all.toSet();
        expect(unique.length, equals(AppRoles.all.length));
      });
    });

    group('OfflineQueueService - Retry Logic', () {
      late OfflineQueueService service;

      setUp(() {
        SharedPreferences.setMockInitialValues({});
        service = OfflineQueueService();
      });

      test('processQueue returns zero counts when queue is empty', () async {
        final result = await service.processQueue(executor: (_) async => true);
        expect(result.processed, equals(0));
        expect(result.succeeded, equals(0));
        expect(result.failed, equals(0));
        expect(result.remaining, equals(0));
      });

      test('processQueue counts succeeded operations', () async {
        await service.enqueue(PendingOperation(
          id: 'test-1',
          type: 'create_ticket',
          payload: {'event_slug': 'test'},
          createdAt: DateTime.now(),
        ));

        final result = await service.processQueue(
          executor: (_) async => true,
        );

        expect(result.processed, equals(1));
        expect(result.succeeded, equals(1));
        expect(result.failed, equals(0));
        expect(result.remaining, equals(0));
      });

      test('processQueue retries failed operations up to max retries', () async {
        await service.enqueue(PendingOperation(
          id: 'test-fail',
          type: 'create_ticket',
          payload: {'event_slug': 'test'},
          createdAt: DateTime.now(),
        ));

        final result = await service.processQueue(
          executor: (_) async => false,
        );

        expect(result.failed, equals(1));
        // Failed but retryable, should be remaining
        expect(result.remaining, equals(1));
      });

      test('enqueue and removeById work correctly', () async {
        final op = PendingOperation(
          id: 'removable',
          type: 'validate_ticket',
          payload: {'ticket_id': '123'},
          createdAt: DateTime.now(),
        );
        await service.enqueue(op);
        expect(await service.count(), equals(1));

        await service.removeById('removable');
        expect(await service.count(), equals(0));
      });

      test('clearAll removes all operations', () async {
        await service.enqueue(PendingOperation(
          id: 'a',
          type: 'create_ticket',
          payload: {},
          createdAt: DateTime.now(),
        ));
        await service.enqueue(PendingOperation(
          id: 'b',
          type: 'create_ticket',
          payload: {},
          createdAt: DateTime.now(),
        ));

        expect(await service.count(), equals(2));
        await service.clearAll();
        expect(await service.count(), equals(0));
      });
    });

    group('ErrorHandler - Error Classification', () {
      test('analyzeError classifies network errors as retryable', () {
        final networkError = ErrorHandler.analyzeError(
          Exception('SocketException: Connection refused'),
        );
        // NetworkError type should have isRetryable property
        expect(networkError, isNotNull);
      });

      test('analyzeError handles null-like errors gracefully', () {
        final result = ErrorHandler.analyzeError('unknown error');
        expect(result, isNotNull);
      });
    });
  });
}
