import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/ttl_cache.dart';
import '../../../core/offline/offline_queue_service.dart';
import '../../../core/offline/pending_operation.dart';

/// Repository for ticket-related operations
class TicketRepository {
  final SupabaseClient _client;
  final Ref _ref;
  final TtlCacheStore _cacheStore;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  TicketRepository(this._client, this._ref, {TtlCacheStore? cacheStore})
      : _cacheStore = cacheStore ?? InMemoryTtlCacheStore();

  /// Creates a new ticket for an event
  ///
  /// Throws [TicketException] if the operation fails
  Future<Map<String, dynamic>> createTicket({
    required String eventSlug,
    required String type,
    required double price,
    required String buyerName,
    required String buyerEmail,
    required String buyerDoc,
    required String buyerPhone,
  }) async {
    final requestId = const Uuid().v4();
    final payload = {
      'event_slug': eventSlug,
      'type': type,
      'price': price,
      'buyer_name': buyerName,
      'buyer_email': buyerEmail,
      'buyer_doc': buyerDoc,
      'buyer_phone': buyerPhone,
      'request_id': requestId,
    };

    try {
      final response = await _client.functions.invoke('create_ticket', body: payload);

      if (response.status != 200) {
        dev.log(
          'Edge Function create_ticket failed',
          error: response.data,
          name: 'TicketRepository',
        );
        throw TicketException('Error al crear ticket: ${response.data}');
      }
      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (e is TicketException) rethrow;

      final networkError = ErrorHandler.analyzeError(e);
      if (networkError.isRetryable) {
        await _ref.read(offlineQueueProvider).enqueue(
              PendingOperation(
                id: requestId,
                type: 'create_ticket',
                payload: payload,
                createdAt: DateTime.now(),
              ),
            );

        return {
          'queued': true,
          'request_id': requestId,
          'email_sent': false,
          'email_error': 'Operación encolada para sincronización offline',
        };
      }

      dev.log('Unexpected error call to create_ticket',
          error: e, name: 'TicketRepository');
      throw TicketException('Error crítico: $e');
    }
  }

  /// Retrieves tickets based on user role
  ///
  /// For devices: uses device credentials
  /// For users: uses authenticated session
  Future<List<Map<String, dynamic>>> getTickets() async {
    DeviceSession? deviceSession = _ref.read(deviceProvider);
    final cacheScope = deviceSession != null
        ? 'device:${deviceSession.deviceId}'
        : 'user';
    final cacheKey = 'tickets:list:$cacheScope';
    final cached = _cacheStore.get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null && cached.isValidAt(DateTime.now())) {
      return cached.value;
    }

    try {
      // Fallback: Check SharedPreferences directly if provider is null
      if (deviceSession == null) {
        final prefs = await SharedPreferences.getInstance();
        final deviceId = prefs.getString('auth_device_id');
        final alias = prefs.getString('auth_device_alias');
        final pin = await _secureStorage.read(key: 'auth_device_pin');
        final selectedEventId = prefs.getString('selected_event_id');

        if (deviceId != null && alias != null && pin != null) {
          final response = await _client.rpc('get_device_tickets', params: {
            'p_device_id': deviceId,
            'p_device_pin': pin,
            'p_event_id': selectedEventId,
          });
          final mapped = List<Map<String, dynamic>>.from(response);
          _cacheStore.set(cacheKey, mapped, ttl: const Duration(seconds: 30));
          return mapped;
        }
      }

      if (deviceSession != null) {
        final prefs = await SharedPreferences.getInstance();
        final selectedEventId = prefs.getString('selected_event_id');
        final response = await _client.rpc('get_device_tickets', params: {
          'p_device_id': deviceSession.deviceId,
          'p_device_pin': deviceSession.pin,
          'p_event_id': selectedEventId,
        });
        final mapped = List<Map<String, dynamic>>.from(response);
        _cacheStore.set(cacheKey, mapped, ttl: const Duration(seconds: 30));
        return mapped;
      }

      // Standard User (Admin/RRPP) - Use Robust RPC
      final response = await _client.rpc('get_authorized_tickets');
      final mapped = List<Map<String, dynamic>>.from(response);
      _cacheStore.set(cacheKey, mapped, ttl: const Duration(seconds: 30));
      return mapped;
    } on PostgrestException catch (e) {
      ErrorHandler.logError('getTickets', e, source: 'TicketRepository');
      if (cached != null) return cached.value;
      throw TicketException('Error al obtener tickets: ${e.message}');
    }
  }

  /// Get ticket types for a specific event
  Future<List<Map<String, dynamic>>> getTicketTypes(String eventId) async {
    final cacheKey = 'ticket_types:$eventId';
    final cached = _cacheStore.get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null && cached.isValidAt(DateTime.now())) {
      return cached.value;
    }

    try {
      final response = await _client
          .from('ticket_types')
          .select('*')
          .eq('event_id', eventId)
          .eq('is_active', true)
          .order('price');
      final mapped = List<Map<String, dynamic>>.from(response);
      _cacheStore.set(cacheKey, mapped, ttl: const Duration(minutes: 2));
      return mapped;
    } on PostgrestException catch (e) {
      ErrorHandler.logError('getTicketTypes', e, source: 'TicketRepository');
      if (cached != null) return cached.value;
      throw TicketException('Error al obtener tipos de ticket: ${e.message}');
    }
  }

  /// Resend ticket email to buyer
  Future<void> resendTicket(String ticketId) async {
    try {
      final response = await _client.functions
          .invoke('resend_ticket_email', body: {'ticket_id': ticketId});
      if (response.status != 200) {
        dev.log(
          'Edge Function resend_ticket_email failed',
          error: response.data,
          name: 'TicketRepository',
        );
        throw TicketException('Error al reenviar ticket: ${response.data}');
      }
    } catch (e) {
      if (e is TicketException) rethrow;
      dev.log('Error in resendTicket', error: e, name: 'TicketRepository');
      throw TicketException('Error crítico al reenviar ticket');
    }
  }

  /// Void/Cancel a ticket
  Future<void> voidTicket(String ticketId) async {
    try {
      final response = await _client.functions
          .invoke('void_ticket', body: {'ticket_id': ticketId});
      if (response.status != 200) {
        dev.log(
          'Edge Function void_ticket failed',
          error: response.data,
          name: 'TicketRepository',
        );
        throw TicketException('Error al anular ticket: ${response.data}');
      }
    } catch (e) {
      if (e is TicketException) rethrow;
      dev.log('Error in voidTicket', error: e, name: 'TicketRepository');
      throw TicketException('Error crítico al anular ticket');
    }
  }
}

/// Custom exception for ticket-related errors
class TicketException implements Exception {
  final String message;

  TicketException(this.message);

  @override
  String toString() => message;
}

/// Provider for TicketRepository
final ticketRepositoryProvider = Provider((ref) {
  return TicketRepository(Supabase.instance.client, ref);
});

/// Provider for fetching ticket types by event
final ticketTypesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) {
  return ref.watch(ticketRepositoryProvider).getTicketTypes(eventId);
});
