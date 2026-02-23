import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import '../../auth/presentation/auth_controller.dart';

class SettingsRepository {
  final SupabaseClient _client;
  final Ref _ref;

  SettingsRepository(this._client, this._ref);

  // --- APP SETTINGS ---

  Future<String> getDefaultCurrency() async {
    try {
      final response = await _client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'default_currency')
          .maybeSingle();
      return response?['setting_value'] as String? ?? 'PYG';
    } catch (e) {
      dev.log('Error fetching default currency',
          error: e, name: 'SettingsRepository');
      return 'PYG'; // Fallback for stability, but logged
    }
  }

  Future<void> updateDefaultCurrency(String currency) async {
    try {
      await _client.from('app_settings').upsert({
        'setting_key': 'default_currency',
        'setting_value': currency,
      });
    } on PostgrestException catch (e) {
      dev.log('Failed to update currency',
          error: e, name: 'SettingsRepository');
      throw Exception('Error al actualizar moneda: ${e.message}');
    } catch (e) {
      dev.log('Unexpected error updating currency',
          error: e, name: 'SettingsRepository');
      throw Exception('Error inesperado al actualizar moneda');
    }
  }

  // --- USER MANAGEMENT (Profiles) ---

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      // Use Edge Function 'get_team_members' to bypass RLS policies
      // which block 'select' access for standard users.
      final response = await _client.functions.invoke('get_team_members');

      if (response.status != 200) {
        throw Exception('Error fetching members: ${response.status}');
      }

      // The response.data should be the list
      final List<dynamic> data = response.data;
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      dev.log('Error fetching users via Edge Function',
          error: e, name: 'SettingsRepository');
      // Fallback: Return empty list or try direct query if function fails
      return [];
    }
  }

  Future<void> createUserProfile({
    required String userId,
    required String role,
    required String displayName,
    String? organizationId,
  }) async {
    try {
      // TODO: Migrar a Edge Function para validación dual y auditoría
      await _client.from('users_profile').insert({
        'user_id': userId,
        'role': role,
        'display_name': displayName,
        if (organizationId != null) 'organization_id': organizationId,
      });
    } on PostgrestException catch (e) {
      dev.log('Error creating user profile',
          error: e, name: 'SettingsRepository');
      throw Exception('Error al crear perfil: ${e.message}');
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _client
          .from('users_profile')
          .update({'role': role}).eq('user_id', userId);
    } on PostgrestException catch (e) {
      dev.log('Error updating role', error: e, name: 'SettingsRepository');
      throw Exception('Error al actualizar rol: ${e.message}');
    }
  }

  Future<void> deleteUserProfile(String userId) async {
    try {
      await _client.from('users_profile').delete().eq('user_id', userId);
    } on PostgrestException catch (e) {
      dev.log('Error deleting user profile',
          error: e, name: 'SettingsRepository');
      throw Exception('Error al eliminar perfil: ${e.message}');
    }
  }

  // --- DEVICE MANAGEMENT (Using Edge Function to bypass RLS) ---

  Future<List<Map<String, dynamic>>> getDevices() async {
    try {
      final response = await _client.functions
          .invoke('manage_devices', method: HttpMethod.get);
      if (response.status != 200) throw Exception('Status ${response.status}');

      final List<dynamic> data = response.data;
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      dev.log('Error fetching devices', error: e, name: 'SettingsRepository');
      return [];
    }
  }

  Future<void> createDevice({
    required String deviceId,
    required String alias,
    required String pinHash,
  }) async {
    try {
      // Intentar con Edge Function primero
      final response = await _client.functions.invoke('manage_devices',
          method: HttpMethod.post,
          body: {
            'device_id': deviceId,
            'alias': alias,
            'pin': pinHash,
            'pin_hash': pinHash
          });

      if (response.status != 200 && response.status != 201) {
        throw Exception('Server error: ${response.data}');
      }
    } on FunctionException catch (fe) {
      // Si la función falla, intentar inserción directa
      dev.log('Edge Function failed, trying direct insert',
          error: fe, name: 'SettingsRepository');
      final orgId = _ref.read(organizationIdProvider);
      await _createDeviceDirect(deviceId, alias, pinHash,
          organizationId: orgId);
    } catch (e) {
      dev.log('Error creating device', error: e, name: 'SettingsRepository');
      throw Exception('Error al registrar dispositivo: $e');
    }
  }

  /// Crear dispositivo directamente en la tabla (fallback)
  Future<void> _createDeviceDirect(
      String deviceId, String alias, String pinHash,
      {required String? organizationId}) async {
    if (organizationId == null) {
      throw Exception('Cannot create device without organization context');
    }
    try {
      await _client.from('devices').insert({
        'device_id': deviceId,
        'alias': alias,
        'pin_hash': pinHash,
        'enabled': true,
        'organization_id': organizationId,
      });
    } on PostgrestException catch (e) {
      dev.log('Direct insert failed', error: e, name: 'SettingsRepository');
      throw Exception('Error en base de datos: ${e.message}');
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    try {
      await _client.functions.invoke('manage_devices',
          method: HttpMethod.delete, body: {'id': deviceId});
    } catch (e) {
      dev.log('Error deleting device', error: e, name: 'SettingsRepository');
      throw Exception('Error al eliminar dispositivo: $e');
    }
  }

  Future<void> toggleDevice(String deviceId, bool enabled) async {
    try {
      await _client.functions.invoke('manage_devices',
          method: HttpMethod.patch, body: {'id': deviceId, 'enabled': enabled});
    } catch (e) {
      dev.log('Error toggling device', error: e, name: 'SettingsRepository');
      throw Exception('Error al cambiar estado: $e');
    }
  }

  Future<void> createUser(
      {required String email,
      required String password,
      required String displayName,
      required String role}) async {
    try {
      final response = await _client.functions.invoke('create_user', body: {
        'email': email,
        'password': password,
        'display_name': displayName,
        'role': role
      });

      if (response.status != 200) {
        throw Exception('Error creating user: ${response.status}');
      }
    } catch (e) {
      dev.log('Error creating user via Edge Function',
          error: e, name: 'SettingsRepository');
      throw Exception('Error al crear usuario: $e');
    }
  }
  // --- EVENT STAFF MANAGEMENT (Quotas) ---

  Future<void> manageEventStaff({
    required String eventId,
    required String userId,
    required String role,
    required int quotaStandard,
    required int quotaGuest,
    required int quotaInvitation,
  }) async {
    await _client.rpc('manage_event_staff', params: {
      'p_event_id': eventId,
      'p_user_id': userId,
      'p_role': role,
      'p_quota_standard': quotaStandard,
      'p_quota_guest': quotaGuest,
      'p_quota_invitation': quotaInvitation,
    });
  }

  Future<List<Map<String, dynamic>>> getEventStaff(String eventId) async {
    // We fetch event_staff and also want user details (display_name).
    // option 1: join in SQL.
    // option 2: fetch all and client-side join (easier if list is small).
    // Let's use a simple join if RLS allows, or just fetch event_staff and rely on usersListProvider to map names.
    // Given we are Admin, we can fetch everything.

    final response =
        await _client.from('event_staff').select().eq('event_id', eventId);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getMyEventStaff(
      String eventId, String userId) async {
    final response = await _client
        .from('event_staff')
        .select()
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();
    return response;
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(Supabase.instance.client, ref);
});

final defaultCurrencyProvider = FutureProvider<String>((ref) async {
  return ref.watch(settingsRepositoryProvider).getDefaultCurrency();
});

final usersListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(settingsRepositoryProvider).getUsers();
});

final devicesListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(settingsRepositoryProvider).getDevices();
});
