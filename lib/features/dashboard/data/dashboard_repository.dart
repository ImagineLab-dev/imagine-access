import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import '../../events/presentation/event_state.dart';

class DashboardRepository {
  final SupabaseClient _client;

  DashboardRepository(this._client);

  Future<Map<String, dynamic>> getMetrics(String? eventId) async {
    if (eventId == null) return {};

    try {
      final response = await _client.rpc(
        'get_staff_dashboard',
        params: {'p_event_id': eventId},
      );

      return Map<String, dynamic>.from(response);
    } catch (e) {
      dev.log('Error fetching metrics', error: e, name: 'DashboardRepository');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getRecentActivity(String? eventId) async {
    if (eventId == null) return [];

    final response = await _client
        .from('checkins')
        .select(
            '*, tickets(buyer_name, type, users_profile!created_by(display_name))')
        .eq('event_id', eventId)
        .order('scanned_at', ascending: false)
        .limit(5);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getStats(String? eventId) async {
    if (eventId == null) return {};
    try {
      final response = await _client.rpc(
        'get_event_statistics',
        params: {'p_event_id': eventId},
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      dev.log('Error fetching stats', error: e, name: 'DashboardRepository');
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

  dev.log('Setting up Realtime for event: $eventId', name: 'DashboardRealtime');

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
          dev.log('Realtime change in checkins', name: 'DashboardRealtime');
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
          dev.log('Realtime change in tickets', name: 'DashboardRealtime');
          ref.invalidate(dashboardMetricsProvider);
          ref.invalidate(recentActivityProvider);
          ref.invalidate(eventStatsProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    dev.log('Disposing Realtime for event: $eventId',
        name: 'DashboardRealtime');
    supabase.removeChannel(channel);
  });
});
