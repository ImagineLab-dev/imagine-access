import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import 'package:uuid/uuid.dart';
import '../../auth/presentation/auth_controller.dart';

class ScannerRepository {
  final SupabaseClient _client;
  final Ref _ref;
  ScannerRepository(this._client, this._ref);

  Future<Map<String, dynamic>> validateQr(
      String qrToken, String? deviceId, String? pin, String eventId) async {
    try {
      final requestId = const Uuid().v4();
      final response = await _client.functions.invoke('validate_ticket', body: {
        'method': 'qr',
        'qr_token': qrToken,
        'device_id': deviceId,
        'event_id': eventId,
        'request_id': requestId,
      });

      if (response.status != 200) {
        throw response.data['error'] ?? 'Error de validación QR';
      }

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      dev.log('Error in validateQr', error: e, name: 'ScannerRepository');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> validateDoc({
    required String doc,
    required String eventId,
    required String reason,
    required String? deviceId,
  }) async {
    try {
      final requestId = const Uuid().v4();
      final response = await _client.functions.invoke('validate_ticket', body: {
        'method': 'doc',
        'buyer_doc': doc,
        'event_id': eventId,
        'notes': reason,
        'device_id': deviceId,
        'request_id': requestId,
      });

      if (response.status != 200) {
        throw response.data['error'] ?? 'Error de validación por documento';
      }

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      dev.log('Error in validateDoc', error: e, name: 'ScannerRepository');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> validateById({
    required String ticketId,
    required String reason,
    required String? deviceId,
  }) async {
    try {
      final requestId = const Uuid().v4();
      final response = await _client.functions.invoke('validate_ticket', body: {
        'method': 'id',
        'ticket_id': ticketId,
        'notes': reason,
        'device_id': deviceId,
        'request_id': requestId,
      });

      if (response.status != 200) {
        throw response.data['error'] ?? 'Error de validación por ID';
      }

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      dev.log('Error in validateById', error: e, name: 'ScannerRepository');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchTickets({
    required String query,
    required String type, // 'doc' or 'phone'
    required String eventId,
  }) async {
    try {
      // 1. Gather Context (Auth vs Device)
      final deviceSession = _ref.read(deviceProvider);

      // 2. Call Unified RPC
      final response = await _client.rpc('search_tickets_unified', params: {
        'p_query': query,
        'p_type': type,
        'p_event_id': eventId,
        'p_device_id': deviceSession?.deviceId, // nullable
        'p_device_pin': deviceSession?.pin, // nullable
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      dev.log('Error in searchTickets', error: e, name: 'ScannerRepository');
      rethrow;
    }
  }
}

final scannerRepositoryProvider =
    Provider((ref) => ScannerRepository(Supabase.instance.client, ref));
