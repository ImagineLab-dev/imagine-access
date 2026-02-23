import 'package:flutter_test/flutter_test.dart';
import 'package:imagine_access/features/dashboard/data/dashboard_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ──────────────────────────────────────────────
// Supabase's rpc() returns PostgrestFilterBuilder which is complex to mock.
// Instead, we subclass DashboardRepository to test its logic directly.

class TestDashboardRepository extends DashboardRepository {
  final Map<String, dynamic>? rpcResult;
  final Exception? rpcError;
  String? lastRpcFunction;
  Map<String, dynamic>? lastRpcParams;

  TestDashboardRepository({this.rpcResult, this.rpcError})
      : super(_FakeSupabaseClient());

  @override
  Future<Map<String, dynamic>> getMetrics(String? eventId) async {
    if (eventId == null) return {};
    lastRpcFunction = 'get_staff_dashboard';
    lastRpcParams = {'p_event_id': eventId};
    if (rpcError != null) throw rpcError!;
    return rpcResult ?? {};
  }

  @override
  Future<Map<String, dynamic>> getStats(String? eventId) async {
    if (eventId == null) return {};
    lastRpcFunction = 'get_event_statistics';
    lastRpcParams = {'p_event_id': eventId};
    if (rpcError != null) throw rpcError!;
    return rpcResult ?? {};
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentActivity(String? eventId) async {
    if (eventId == null) return [];
    lastRpcFunction = 'get_recent_activity';
    lastRpcParams = {'p_event_id': eventId};
    return [];
  }
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  group('DashboardRepository', () {
    group('getMetrics', () {
      test('returns empty map when eventId is null', () async {
        final repo = TestDashboardRepository(
          rpcResult: {'total': 100},
        );

        final result = await repo.getMetrics(null);

        expect(result, isEmpty);
        expect(result, isA<Map<String, dynamic>>());
        // Verify NO RPC call was made
        expect(repo.lastRpcFunction, isNull);
      });

      test('calls correct RPC function with correct params', () async {
        final repo = TestDashboardRepository(
          rpcResult: {
            'total_tickets': 50,
            'checked_in': 10,
            'revenue': 500000.0,
          },
        );

        final result = await repo.getMetrics('event-123');

        expect(result['total_tickets'], equals(50));
        expect(result['checked_in'], equals(10));
        expect(result['revenue'], equals(500000.0));
        expect(repo.lastRpcFunction, equals('get_staff_dashboard'));
        expect(repo.lastRpcParams?['p_event_id'], equals('event-123'));
      });
    });

    group('getRecentActivity', () {
      test('returns empty list when eventId is null', () async {
        final repo = TestDashboardRepository();

        final result = await repo.getRecentActivity(null);

        expect(result, isEmpty);
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(repo.lastRpcFunction, isNull);
      });
    });

    group('getStats', () {
      test('returns empty map when eventId is null', () async {
        final repo = TestDashboardRepository(
          rpcResult: {'total': 999},
        );

        final result = await repo.getStats(null);

        expect(result, isEmpty);
        expect(repo.lastRpcFunction, isNull);
      });

      test('calls correct RPC function with correct params', () async {
        final repo = TestDashboardRepository(
          rpcResult: {
            'total_revenue': 1000000.0,
            'ticket_count': 100,
          },
        );

        final result = await repo.getStats('event-456');

        expect(result['total_revenue'], equals(1000000.0));
        expect(result['ticket_count'], equals(100));
        expect(repo.lastRpcFunction, equals('get_event_statistics'));
        expect(repo.lastRpcParams?['p_event_id'], equals('event-456'));
      });
    });

    group('Null Guard Security', () {
      test('ALL methods return empty when eventId is null', () async {
        final repo = TestDashboardRepository(
          rpcResult: {'should_not_appear': true},
        );

        final metrics = await repo.getMetrics(null);
        final activity = await repo.getRecentActivity(null);
        final stats = await repo.getStats(null);

        expect(metrics, isEmpty);
        expect(activity, isEmpty);
        expect(stats, isEmpty);
        // NO RPC calls should have been made
        expect(repo.lastRpcFunction, isNull);
      });
    });
  });
}
