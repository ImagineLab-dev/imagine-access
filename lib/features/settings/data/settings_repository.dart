import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:crypto/crypto.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/ttl_cache.dart';

class SettingsRepository {
  final SupabaseClient _client;
  final Ref _ref;
  final TtlCacheStore _cacheStore;

  SettingsRepository(this._client, this._ref, {TtlCacheStore? cacheStore})
      : _cacheStore = cacheStore ?? InMemoryTtlCacheStore();

  // --- APP SETTINGS (scoped per organization) ---

  String? _currentOrgId() {
    return _ref.read(organizationIdProvider);
  }

  Future<String> getDefaultCurrency() async {
    final orgId = _currentOrgId();
    try {
      var query = _client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'default_currency');

      if (orgId != null && orgId.isNotEmpty) {
        query = query.eq('organization_id', orgId);
      }

      final response = await query.maybeSingle();
      return response?['setting_value'] as String? ?? 'PYG';
    } catch (e) {
      dev.log('Error fetching default currency',
          error: e, name: 'SettingsRepository');
      return 'PYG';
    }
  }

  Future<void> updateDefaultCurrency(String currency) async {
    final orgId = _currentOrgId();
    try {
      final data = <String, dynamic>{
        'setting_key': 'default_currency',
        'setting_value': currency,
      };
      if (orgId != null && orgId.isNotEmpty) {
        data['organization_id'] = orgId;
      }
      await _client.from('app_settings').upsert(data);
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
    const cacheKey = 'settings:users';
    final cached = _cacheStore.get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null && cached.isValidAt(DateTime.now())) {
      return cached.value;
    }

    try {
      // Use Edge Function 'get_team_members' to bypass RLS policies
      // which block 'select' access for standard users.
      final response = await _client.functions.invoke('get_team_members');

      if (response.status != 200) {
        throw Exception('Error fetching members: ${response.status} - ${response.data}');
      }

      // The response.data should be the list
      final List<dynamic> data = response.data;
      final mapped = List<Map<String, dynamic>>.from(data);
      _cacheStore.set(cacheKey, mapped, ttl: const Duration(minutes: 1));
      return mapped;
    } catch (e) {
      ErrorHandler.logError('getUsers', e, source: 'SettingsRepository');
      // Allow the error to propagate so the UI can display it
      throw Exception('Error: $e');
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
    final orgId = _currentOrgId();
    try {
      var query = _client
          .from('users_profile')
          .update({'role': role})
          .eq('user_id', userId);

      // Scope to current organization to prevent cross-tenant changes
      if (orgId != null && orgId.isNotEmpty) {
        query = query.eq('organization_id', orgId);
      }

      await query;
    } on PostgrestException catch (e) {
      dev.log('Error updating role', error: e, name: 'SettingsRepository');
      throw Exception('Error al actualizar rol: ${e.message}');
    }
  }

  Future<void> deleteUserProfile(String userId) async {
    try {
      final response = await _client.functions.invoke(
        'delete_user',
        body: {'user_id': userId},
      );

      if (response.status != 200) {
        throw Exception('Server error: ${response.data}');
      }
    } catch (e) {
      dev.log('Error deleting user profile',
          error: e, name: 'SettingsRepository');
      throw Exception('Error al eliminar perfil: $e');
    }
  }

  // --- DEVICE MANAGEMENT (Using Edge Function to bypass RLS) ---

  Future<List<Map<String, dynamic>>> getDevices() async {
    const cacheKey = 'settings:devices';
    final cached = _cacheStore.get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null && cached.isValidAt(DateTime.now())) {
      return cached.value;
    }

    try {
      final response = await _client.functions
          .invoke('manage_devices', method: HttpMethod.get);
      if (response.status != 200) throw Exception('Status ${response.status}');

      final List<dynamic> data = response.data;
      final mapped = List<Map<String, dynamic>>.from(data);
      _cacheStore.set(cacheKey, mapped, ttl: const Duration(minutes: 1));
      return mapped;
    } catch (e) {
      ErrorHandler.logError('getDevices', e, source: 'SettingsRepository');
      return cached?.value ?? [];
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
            'id': deviceId,
            'device_id': deviceId,
            'alias': alias,
            'pin': pinHash
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
      // Generate salt and hash the PIN the same way the Edge Function does:
      // sha256("$salt:$pin")
      final random = Random.secure();
      final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
      final pinSalt = saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final hashedPin = sha256.convert(utf8.encode('$pinSalt:$pinHash')).toString();

      await _client.from('devices').insert({
        'device_id': deviceId,
        'alias': alias,
        'pin': null,
        'pin_hash': hashedPin,
        'pin_salt': pinSalt,
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
