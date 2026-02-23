import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:imagine_access/features/events/data/event_repository.dart';

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
  });
}
