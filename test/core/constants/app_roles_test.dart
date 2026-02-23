import 'package:flutter_test/flutter_test.dart';
import 'package:imagine_access/core/constants/app_roles.dart';

void main() {
  group('AppRoles Constants', () {
    test('admin should be "admin"', () {
      expect(AppRoles.admin, equals('admin'));
    });

    test('rrpp should be "rrpp"', () {
      expect(AppRoles.rrpp, equals('rrpp'));
    });

    test('door should be "door"', () {
      expect(AppRoles.door, equals('door'));
    });

    test('all should contain exactly 3 roles', () {
      expect(AppRoles.all, hasLength(3));
      expect(AppRoles.all, containsAll(['admin', 'rrpp', 'door']));
    });

    test('all should be in correct order', () {
      expect(
          AppRoles.all, equals([AppRoles.admin, AppRoles.rrpp, AppRoles.door]));
    });
  });

  group('AppRoles.label', () {
    test('should return "Admin" for admin role', () {
      expect(AppRoles.label(AppRoles.admin), equals('Admin'));
    });

    test('should return "RRPP" for rrpp role', () {
      expect(AppRoles.label(AppRoles.rrpp), equals('RRPP'));
    });

    test('should return "Door/Puerta" for door role', () {
      expect(AppRoles.label(AppRoles.door), equals('Door/Puerta'));
    });

    test('should return uppercase for unknown role', () {
      expect(AppRoles.label('vip'), equals('VIP'));
    });

    test('should return uppercase for empty string', () {
      expect(AppRoles.label(''), equals(''));
    });
  });

  group('AppRoles.isAdmin', () {
    test('should return true for admin', () {
      expect(AppRoles.isAdmin(AppRoles.admin), isTrue);
    });

    test('should return false for rrpp', () {
      expect(AppRoles.isAdmin(AppRoles.rrpp), isFalse);
    });

    test('should return false for door', () {
      expect(AppRoles.isAdmin(AppRoles.door), isFalse);
    });

    test('should return false for null', () {
      expect(AppRoles.isAdmin(null), isFalse);
    });

    test('should return false for empty string', () {
      expect(AppRoles.isAdmin(''), isFalse);
    });

    test('should return false for ADMIN (case sensitive)', () {
      expect(AppRoles.isAdmin('ADMIN'), isFalse);
    });
  });

  group('AppRoles - No Magic Strings Verification', () {
    test('constants should match expected Supabase values exactly', () {
      // These MUST match the values in Supabase app_metadata.role
      expect(AppRoles.admin, equals('admin'));
      expect(AppRoles.rrpp, equals('rrpp'));
      expect(AppRoles.door, equals('door'));
    });

    test('role values should be lowercase', () {
      for (final role in AppRoles.all) {
        expect(role, equals(role.toLowerCase()),
            reason: 'Role "$role" should be lowercase');
      }
    });
  });
}
