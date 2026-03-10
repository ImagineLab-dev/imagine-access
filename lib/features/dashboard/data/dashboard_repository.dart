import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../events/presentation/event_state.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/ttl_cache.dart';

class DashboardRepository {
  final SupabaseClient _client;
  final TtlCacheStore _cacheStore;

  DashboardRepository(this._client, {TtlCacheStore? cacheStore})
      : _cacheStore = cacheStore ?? InMemoryTtlCacheStore();

  Future<Map<String, dynamic>> getMetrics(String? eventId) async {
    if (eventId == null) return {};

    final cacheKey = 'dashboard:metrics:$eventId';
    final cached = _cacheStore.get<Map<String, dynamic>>(cacheKey);
    if (cached != null && cached.isValidAt(DateTime.now())) {
      return cached.value;
    }

    try {
      final response = await _client.rpc(
        'get_staff_dashboard',
        params: {'p_event_id': eventId},
      );
      final mapped = Map<String, dynamic>.from(response);
      _cacheStore.set(cacheKey, mapped, ttl: const Duration(minutes: 1));
      return mapped;
    } catch (e) {
      ErrorHandler.logError('getMetrics', e, source: 'DashboardRepository');
      if (cached != null) return cached.value;
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getRecentActivity(String? eventId) async {
    if (eventId == null) return [];

    final cacheKey = 'dashboard:recent:$eventId';
    final cached = _cacheStore.get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null && cached.isValidAt(DateTime.now())) {
      return cached.value;
    }

    try {
      final response = await _client
          .from('checkins')
          .select(
              '*, tickets(buyer_name, type, users_profile!created_by(display_name))')
          .eq('event_id', eventId)
          .order('scanned_at', ascending: false)
          .limit(5);
      final mapped = List<Map<String, dynamic>>.from(response);
      _cacheStore.set(cacheKey, mapped, ttl: const Duration(seconds: 30));
      return mapped;
    } catch (e) {
      ErrorHandler.logError(
        'getRecentActivity',
        e,
        source: 'DashboardRepository',
      );
      if (cached != null) return cached.value;
      return [];
    }
  }

  Future<Map<String, dynamic>> getStats(String? eventId) async {
    if (eventId == null) return {};

    final cacheKey = 'dashboard:stats:$eventId';
    final cached = _cacheStore.get<Map<String, dynamic>>(cacheKey);
    if (cached != null && cached.isValidAt(DateTime.now())) {
      return cached.value;
    }

    try {
      final response = await _client.rpc(
        'get_event_statistics',
        params: {'p_event_id': eventId},
      );
      final mapped = Map<String, dynamic>.from(response);
      _cacheStore.set(cacheKey, mapped, ttl: const Duration(minutes: 1));
      return mapped;
    } catch (e) {
      ErrorHandler.logError('getStats', e, source: 'DashboardRepository');
      if (cached != null) return cached.value;
      return {};
    }
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(Supabase.instance.client);
});

final eventStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, eventId) async {
  return ref.watch(dashboardRepositoryProvider).getStats(eventId);
});

final dashboardMetricsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final selectedEvent = ref.watch(selectedEventProvider);
  return ref
      .watch(dashboardRepositoryProvider)
      .getMetrics(selectedEvent?['id']);
});

final recentActivityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final selectedEvent = ref.watch(selectedEventProvider);
  return ref
      .watch(dashboardRepositoryProvider)
      .getRecentActivity(selectedEvent?['id']);
});

// REALTIME UPDATER: Listens for changes and invalidates providers
final dashboardRealtimeProvider = Provider.autoDispose<void>((ref) {
  final selectedEvent = ref.watch(selectedEventProvider);
  if (selectedEvent == null) return;

  final eventId = selectedEvent['id'];
  final supabase = Supabase.instance.client;

  ErrorHandler.logError(
    'Dashboard realtime setup',
    'event=$eventId',
    source: 'DashboardRealtime',
  );

  final channel = supabase
      .channel('dashboard_updates_$eventId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'checkins',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'event_id',
          value: eventId,
        ),
        callback: (payload) {
          ErrorHandler.logError(
            'Realtime checkins change',
            payload,
            source: 'DashboardRealtime',
          );
          ref.invalidate(dashboardMetricsProvider);
          ref.invalidate(recentActivityProvider);
          ref.invalidate(eventStatsProvider);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tickets',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'event_id',
          value: eventId,
        ),
        callback: (payload) {
          ErrorHandler.logError(
            'Realtime tickets change',
            payload,
            source: 'DashboardRealtime',
          );
          ref.invalidate(dashboardMetricsProvider);
          ref.invalidate(recentActivityProvider);
          ref.invalidate(eventStatsProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    ErrorHandler.logError(
      'Dashboard realtime disposed',
      'event=$eventId',
      source: 'DashboardRealtime',
    );
    supabase.removeChannel(channel);
  });
});
