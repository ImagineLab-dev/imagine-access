import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/presentation/auth_controller.dart';

/// Repository for ticket-related operations
class TicketRepository {
  final SupabaseClient _client;
  final Ref _ref;

  TicketRepository(this._client, this._ref);

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
    try {
      final requestId = const Uuid().v4();
      final response = await _client.functions.invoke('create_ticket', body: {
        'event_slug': eventSlug,
        'type': type,
        'price': price,
        'buyer_name': buyerName,
        'buyer_email': buyerEmail,
        'buyer_doc': buyerDoc,
        'buyer_phone': buyerPhone,
        'request_id': requestId,
      });

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
    try {
      DeviceSession? deviceSession = _ref.read(deviceProvider);

      // Fallback: Check SharedPreferences directly if provider is null
      if (deviceSession == null) {
        final prefs = await SharedPreferences.getInstance();
        final deviceId = prefs.getString('auth_device_id');
        final alias = prefs.getString('auth_device_alias');
        final pin = prefs.getString('auth_device_pin');

        if (deviceId != null && alias != null && pin != null) {
          final response = await _client.rpc('get_device_tickets', params: {
            'p_device_id': deviceId,
            'p_device_pin': pin,
          });
          return List<Map<String, dynamic>>.from(response);
        }
      }

      if (deviceSession != null) {
        final response = await _client.rpc('get_device_tickets', params: {
          'p_device_id': deviceSession.deviceId,
          'p_device_pin': deviceSession.pin,
        });
        return List<Map<String, dynamic>>.from(response);
      }

      // Standard User (Admin/RRPP) - Use Robust RPC
      final response = await _client.rpc('get_authorized_tickets');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      dev.log('Error fetching tickets', error: e, name: 'TicketRepository');
      throw TicketException('Error al obtener tickets: ${e.message}');
    }
  }

  /// Get ticket types for a specific event
  Future<List<Map<String, dynamic>>> getTicketTypes(String eventId) async {
    try {
      final response = await _client
          .from('ticket_types')
          .select('*')
          .eq('event_id', eventId)
          .eq('is_active', true)
          .order('price');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      dev.log('Error fetching ticket types',
          error: e, name: 'TicketRepository');
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
