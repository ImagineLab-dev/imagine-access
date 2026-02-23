import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/auth_controller.dart';

class EventRepository {
  final SupabaseClient _client;

  EventRepository(this._client);

  Future<List<Map<String, dynamic>>> getEvents(
      {bool includeArchived = false, String? organizationId}) async {
    // SECURITY: If no organizationId, return empty to prevent cross-tenant leak
    if (organizationId == null) return [];

    var query = _client.from('events').select('*, ticket_types(*)');

    if (!includeArchived) {
      query = query.eq('is_archived', false);
    }

    query = query.eq('organization_id', organizationId);

    final response = await query.order('date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createEvent({
    required String name,
    required String venue,
    required String address,
    required String city,
    required DateTime date,
    required String slug,
    required String currency,
    String? organizationId,
  }) async {
    final insertData = {
      'name': name,
      'venue': venue,
      'address': address,
      'city': city,
      'date': date.toIso8601String(),
      'slug': slug,
      'currency': currency,
      'is_active': true,
      'is_archived': false,
      if (organizationId != null) 'organization_id': organizationId,
    };

    final response =
        await _client.from('events').insert(insertData).select().single();
    return response;
  }

  Future<Map<String, dynamic>> updateEvent(
      String id, Map<String, dynamic> data) async {
    final response = await _client
        .from('events')
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return response;
  }

  Future<void> deleteEvent(String id) async {
    // Soft delete (archive) preferred, but Admin can hard delete if no tickets exist
    await _client.from('events').delete().eq('id', id);
  }

  Future<void> archiveEvent(String id) async {
    await _client
        .from('events')
        .update({'is_archived': true, 'is_active': false}).eq('id', id);
  }

  // Ticket Types Management
  Future<void> createTicketType({
    required String eventId,
    required String name,
    required double price,
    required String currency,
    String category = 'standard',
    DateTime? validUntil,
    String? color,
  }) async {
    await _client.from('ticket_types').insert({
      'event_id': eventId,
      'name': name,
      'price': price,
      'currency': currency,
      'category': category,
      'valid_until': validUntil?.toIso8601String(),
      'color': color,
      'is_active': true,
    });
  }

  Future<void> updateTicketType(String id, Map<String, dynamic> data) async {
    await _client.from('ticket_types').update(data).eq('id', id);
  }

  Future<void> deleteTicketType(String id) async {
    await _client.from('ticket_types').delete().eq('id', id);
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(Supabase.instance.client);
});

final eventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  final orgId = ref.watch(organizationIdProvider);
  return repository.getEvents(organizationId: orgId);
});
