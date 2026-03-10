class TtlCacheEntry<T> {
  final T value;
  final DateTime createdAt;
  final Duration ttl;

  const TtlCacheEntry({
    required this.value,
    required this.createdAt,
    required this.ttl,
  });

  bool isValidAt(DateTime now) {
    return now.difference(createdAt) < ttl;
  }
}

abstract class TtlCacheStore {
  TtlCacheEntry<T>? get<T>(String key);
  void set<T>(String key, T value, {required Duration ttl});
  void invalidate(String key);
  void clear();
}

class InMemoryTtlCacheStore implements TtlCacheStore {
  final Map<String, TtlCacheEntry<dynamic>> _store =
      <String, TtlCacheEntry<dynamic>>{};

  @override
  TtlCacheEntry<T>? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    return entry as TtlCacheEntry<T>;
  }

  @override
  void set<T>(String key, T value, {required Duration ttl}) {
    _store[key] = TtlCacheEntry<T>(
      value: value,
      createdAt: DateTime.now(),
      ttl: ttl,
    );
  }

  @override
  void invalidate(String key) {
    _store.remove(key);
  }

  @override
  void clear() {
    _store.clear();
  }
}
