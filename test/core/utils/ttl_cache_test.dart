import 'package:flutter_test/flutter_test.dart';
import 'package:imagine_access/core/utils/ttl_cache.dart';

void main() {
  group('TtlCacheEntry', () {
    test('isValidAt returns true inside ttl', () {
      final createdAt = DateTime.now().subtract(const Duration(seconds: 10));
      final entry = TtlCacheEntry<String>(
        value: 'value',
        createdAt: createdAt,
        ttl: const Duration(minutes: 1),
      );

      expect(entry.isValidAt(DateTime.now()), isTrue);
    });

    test('isValidAt returns false after ttl expires', () {
      final createdAt = DateTime.now().subtract(const Duration(minutes: 2));
      final entry = TtlCacheEntry<String>(
        value: 'value',
        createdAt: createdAt,
        ttl: const Duration(minutes: 1),
      );

      expect(entry.isValidAt(DateTime.now()), isFalse);
    });
  });

  group('InMemoryTtlCacheStore', () {
    late InMemoryTtlCacheStore cache;

    setUp(() {
      cache = InMemoryTtlCacheStore();
    });

    test('stores and retrieves value', () {
      cache.set<String>('k1', 'v1', ttl: const Duration(minutes: 5));

      final entry = cache.get<String>('k1');

      expect(entry, isNotNull);
      expect(entry!.value, equals('v1'));
      expect(entry.isValidAt(DateTime.now()), isTrue);
    });

    test('invalidate removes key', () {
      cache.set<String>('k2', 'v2', ttl: const Duration(minutes: 5));

      cache.invalidate('k2');

      expect(cache.get<String>('k2'), isNull);
    });

    test('clear removes all keys', () {
      cache.set<String>('a', '1', ttl: const Duration(minutes: 5));
      cache.set<String>('b', '2', ttl: const Duration(minutes: 5));

      cache.clear();

      expect(cache.get<String>('a'), isNull);
      expect(cache.get<String>('b'), isNull);
    });
  });
}
