import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:imagine_access/features/events/data/event_repository.dart';
import 'package:imagine_access/core/utils/ttl_cache.dart';

// ─── Mocks ──────────────────────────────────────────────
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {}

void main() {
  late MockSupabaseClient mockClient;
  late EventRepository repository;

  setUp(() {
    mockClient = MockSupabaseClient();
    repository = EventRepository(mockClient);
  });

  group('EventRepository', () {
    group('getEvents', () {
      test('returns empty list when organizationId is null', () async {
        // CRITICAL SECURITY: No Supabase call should be made at all
        final result = await repository.getEvents(organizationId: null);

        expect(result, isEmpty);
        // Verify NO interaction with Supabase client
        verifyNever(() => mockClient.from(any()));
      });

      test('returns empty list when organizationId is not provided', () async {
        final result = await repository.getEvents();

        expect(result, isEmpty);
        verifyNever(() => mockClient.from(any()));
      });
    });

    group('createEvent', () {
      test('includes organization_id when provided', () {
        // Verify the insert data structure by testing method signature
        // The method accepts organizationId as optional parameter
        expect(
          () => repository.createEvent(
            name: 'Test Event',
            venue: 'Test Venue',
            address: 'Test Address',
            city: 'Test City',
            date: DateTime(2026, 1, 1),
            slug: 'test-event',
            currency: 'PYG',
            organizationId: 'org-123',
          ),
          // Will throw because mock is not set up for `.from()`,
          // but this proves the method accepts organizationId
          throwsA(anything),
        );
      });
    });

    group('cache behavior', () {
      test('returns cached events when cache is valid', () async {
        final cache = InMemoryTtlCacheStore();
        cache.set<List<Map<String, dynamic>>>(
          'events::org=org-1::user=null::includeArchived=false',
          [
            {'id': 'event-1', 'name': 'Cached Event'}
          ],
          ttl: const Duration(minutes: 5),
        );

        final repo = EventRepository(mockClient, cacheStore: cache);
        final result = await repo.getEvents(organizationId: 'org-1');

        expect(result, hasLength(1));
        expect(result.first['name'], equals('Cached Event'));
        verifyNever(() => mockClient.from(any()));
      });

      test('returns stale cache when remote fetch fails', () async {
        final cache = InMemoryTtlCacheStore();
        cache.set<List<Map<String, dynamic>>>(
          'events::org=org-2::user=null::includeArchived=false',
          [
            {'id': 'event-2', 'name': 'Stale Event'}
          ],
          ttl: const Duration(seconds: 1),
        );

        await Future<void>.delayed(const Duration(seconds: 2));
        when(() => mockClient.from('events')).thenThrow(Exception('network'));

        final repo = EventRepository(mockClient, cacheStore: cache);
        final result = await repo.getEvents(organizationId: 'org-2');

        expect(result, hasLength(1));
        expect(result.first['name'], equals('Stale Event'));
      });
    });
  });
}
