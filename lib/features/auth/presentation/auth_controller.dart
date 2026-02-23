import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_roles.dart';

// State classes
class DeviceSession {
  final String deviceId; // Internal UUID for RPC calls
  final String alias; // Human-readable name for login
  final String pin;
  DeviceSession(
      {required this.deviceId, required this.alias, required this.pin});
}

class UserOrganization {
  final String id;
  final String name;
  final String slug;

  UserOrganization({required this.id, required this.name, required this.slug});

  factory UserOrganization.fromJson(Map<String, dynamic> json) {
    return UserOrganization(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }
}

// Global Providers
final userProvider =
    StateProvider<User?>((ref) => Supabase.instance.client.auth.currentUser);

final deviceProvider = StateNotifierProvider<DeviceNotifier, DeviceSession?>(
    (ref) => DeviceNotifier());

// Organization Provider - derived from user metadata or local storage
final userOrganizationProvider =
    StateNotifierProvider<OrganizationNotifier, UserOrganization?>((ref) {
  return OrganizationNotifier();
});

class OrganizationNotifier extends StateNotifier<UserOrganization?> {
  OrganizationNotifier() : super(null) {
    _loadOrganization();
  }

  static const String _orgIdKey = 'user_org_id';
  static const String _orgNameKey = 'user_org_name';
  static const String _orgSlugKey = 'user_org_slug';

  Future<void> _loadOrganization() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_orgIdKey);
    final name = prefs.getString(_orgNameKey);
    final slug = prefs.getString(_orgSlugKey);
    if (id != null && name != null && slug != null) {
      state = UserOrganization(id: id, name: name, slug: slug);
    }
  }

  Future<void> setOrganization(String id, String name, String slug) async {
    state = UserOrganization(id: id, name: name, slug: slug);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_orgIdKey, id);
    await prefs.setString(_orgNameKey, name);
    await prefs.setString(_orgSlugKey, slug);
  }

  Future<void> clearOrganization() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_orgIdKey);
    await prefs.remove(_orgNameKey);
    await prefs.remove(_orgSlugKey);
  }
}

class DeviceNotifier extends StateNotifier<DeviceSession?> {
  DeviceNotifier() : super(null) {
    _loadSession();
  }

  static const String _deviceIdKey = 'auth_device_id';
  static const String _deviceAliasKey = 'auth_device_alias';
  static const String _devicePinKey = 'auth_device_pin';

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_deviceIdKey);
    final alias = prefs.getString(_deviceAliasKey);
    final pin = prefs.getString(_devicePinKey);
    if (id != null && alias != null && pin != null) {
      state = DeviceSession(deviceId: id, alias: alias, pin: pin);
    }
  }

  Future<void> setSession(String deviceId, String alias, String pin) async {
    state = DeviceSession(deviceId: deviceId, alias: alias, pin: pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceIdKey, deviceId);
    await prefs.setString(_deviceAliasKey, alias);
    await prefs.setString(_devicePinKey, pin);
  }

  Future<void> clearSession() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    await prefs.remove(_deviceAliasKey);
    await prefs.remove(_devicePinKey);
  }
}

// Role Provider (derived from user metadata)
final userRoleProvider = Provider<String>((ref) {
  final user = ref.watch(userProvider);
  if (user == null) return 'guest';

  // Check app_metadata for 'role' (set by our SQL trigger/Edge Function)
  final appMeta = user.appMetadata;
  // 'admin', 'rrpp', 'door'
  return appMeta['role'] as String? ?? AppRoles.rrpp;
});

// Organization ID from metadata (for API calls)
final organizationIdProvider = Provider<String?>((ref) {
  final user = ref.watch(userProvider);
  if (user == null) return null;
  return user.appMetadata['organization_id'] as String?;
});

// Auth Logic
class AuthController extends StateNotifier<bool> {
  AuthController(this.ref) : super(false);
  final Ref ref;

  // 1. Admin/RRPP Login (Supabase Auth)
  Future<void> loginEmail(String email, String password) async {
    state = true; // Loading
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        ref.read(userProvider.notifier).state = response.user;

        // Load organization from metadata
        final appMeta = response.user?.appMetadata ?? {};
        final orgId = appMeta['organization_id'] as String?;
        final orgName = appMeta['organization_name'] as String?;
        final orgSlug = appMeta['organization_slug'] as String?;

        if (orgId != null && orgName != null && orgSlug != null) {
          await ref
              .read(userOrganizationProvider.notifier)
              .setOrganization(orgId, orgName, orgSlug);
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }

  // 1b. Admin/RRPP Sign Up - Creates NEW ORGANIZATION automatically
  Future<void> signUpEmail(
      String email, String password, String displayName, String organizationName) async {
    state = true;
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      if (response.user != null) {
        ref.read(userProvider.notifier).state = response.user;

        // Create profile AND organization via Edge Function (with retry)
        bool profileCreated = false;
        for (int attempt = 0; attempt < 3 && !profileCreated; attempt++) {
          try {
            final result = await Supabase.instance.client.functions.invoke(
              'ensure_profile',
              body: {
                'user_id': response.user!.id,
                'email': email,
                'display_name': displayName,
                'organization_name': organizationName,
              },
            );

            dev.log('ensure_profile response: ${result.data}');

            // Store organization info
            final data = result.data as Map<String, dynamic>;
            final org = data['organization'] as Map<String, dynamic>?;

            if (org != null) {
              await ref.read(userOrganizationProvider.notifier).setOrganization(
                    org['id'] as String,
                    org['name'] as String,
                    org['slug'] as String,
                  );
            }

            // Refresh session to get updated JWT with role and org info
            final refreshed =
                await Supabase.instance.client.auth.refreshSession();
            ref.read(userProvider.notifier).state = refreshed.user;
            profileCreated = true;
          } catch (e) {
            dev.log('ensure_profile attempt ${attempt + 1} failed: $e');
            if (attempt < 2) {
              await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
            }
          }
        }

        if (!profileCreated) {
          dev.log(
              'WARNING: User created but profile/org not set after 3 attempts');
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }

  // 2. Door Login (Alias + PIN)
  Future<void> loginDevice(String alias, String pin) async {
    state = true;
    try {
      // Call Edge Function to validate credentials securely
      final response = await Supabase.instance.client.functions.invoke(
        'login_device',
        body: {'alias': alias, 'pin': pin},
      );

      if (response.status != 200) {
        throw const AuthException('Invalid or disabled device credentials');
      }

      // Extract deviceId from response for RPC calls
      final data = response.data as Map<String, dynamic>;
      final deviceId = data['device']?['id'] as String? ?? '';

      // Store session locally (deviceId for RPCs, alias for display)
      await ref.read(deviceProvider.notifier).setSession(deviceId, alias, pin);
    } catch (e) {
      // Map generic function errors to user-friendly message
      if (e is FunctionException) {
        throw const AuthException('Invalid credentials');
      }
      rethrow;
    } finally {
      state = false;
    }
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    ref.read(userProvider.notifier).state = null;
    await ref.read(deviceProvider.notifier).clearSession();
    await ref.read(userOrganizationProvider.notifier).clearOrganization();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, bool>((ref) {
  return AuthController(ref);
});
