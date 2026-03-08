import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/utils/ttl_cache.dart';

class EventRepository {
  final SupabaseClient _client;
  final TtlCacheStore _cacheStore;

  EventRepository(this._client, {TtlCacheStore? cacheStore})
      : _cacheStore = cacheStore ?? InMemoryTtlCacheStore();

  String? _safeCurrentUserId() {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  User? _safeCurrentUser() {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getEvents(
      {bool includeArchived = false, String? organizationId}) async {
    final currentUserId = _safeCurrentUserId();

    String? resolvedOrganizationId = organizationId;
    if ((resolvedOrganizationId == null || resolvedOrganizationId.isEmpty) &&
        currentUserId != null) {
      try {
        final profile = await _client
            .from('users_profile')
            .select('organization_id')
            .eq('user_id', currentUserId)
            .maybeSingle();
        resolvedOrganizationId = profile?['organization_id'] as String?;
      } catch (_) {
        // Keep legacy fallback to created_by when profile lookup fails.
      }
    }

    // SECURITY: no org and no user context means no access scope
    if ((resolvedOrganizationId == null || resolvedOrganizationId.isEmpty) &&
        currentUserId == null) {
      return [];
    }

    final cacheKey =
      'events::org=$resolvedOrganizationId::user=$currentUserId::includeArchived=$includeArchived';
    final cached = _cacheStore.get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null && cached.isValidAt(DateTime.now())) {
      return cached.value;
    }

    try {
      var query = _client.from('events').select('*, ticket_types(*)');

      if (!includeArchived) {
        query = query.eq('is_archived', false);
      }

      if (resolvedOrganizationId != null &&
          resolvedOrganizationId.isNotEmpty &&
          currentUserId != null) {
        query = query
            .or('organization_id.eq.$resolvedOrganizationId,created_by.eq.$currentUserId');
      } else if (resolvedOrganizationId != null &&
          resolvedOrganizationId.isNotEmpty) {
        query = query.eq('organization_id', resolvedOrganizationId);
      } else if (currentUserId != null) {
        query = query.eq('created_by', currentUserId);
      }

      final response = await query.order('date', ascending: true);
      final mapped = List<Map<String, dynamic>>.from(response);
      _cacheStore.set<List<Map<String, dynamic>>>(
        cacheKey,
        mapped,
        ttl: const Duration(minutes: 5),
      );
      return mapped;
    } catch (_) {
      if (cached != null) {
        return cached.value;
      }
      rethrow;
    }
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
    final currentUser = _safeCurrentUser();
    final metadataOrgId = currentUser?.appMetadata['organization_id'] as String?;
    final metadataUserOrgId =
        currentUser?.userMetadata?['organization_id'] as String?;
    String? resolvedOrganizationId =
        organizationId ?? metadataOrgId ?? metadataUserOrgId;

    if ((resolvedOrganizationId == null || resolvedOrganizationId.isEmpty) &&
        currentUser != null) {
      try {
        final profile = await _client
            .from('users_profile')
            .select('organization_id')
            .eq('user_id', currentUser.id)
            .maybeSingle();
        resolvedOrganizationId = profile?['organization_id'] as String?;
      } catch (_) {
        // Error handled by final validation below.
      }
    }

    if (resolvedOrganizationId == null || resolvedOrganizationId.isEmpty) {
      throw Exception(
          'No organization found for current user. Please sign in again.');
    }

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
      'organization_id': resolvedOrganizationId,
      if (currentUser != null) 'created_by': currentUser.id,
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
