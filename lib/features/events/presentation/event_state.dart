import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectedEventNotifier extends StateNotifier<Map<String, dynamic>?> {
  SelectedEventNotifier() : super(null) {
    _loadSelectedEvent();
  }

  static const String _eventIdKey = 'selected_event_id';
  static const String _eventNameKey = 'selected_event_name';
  static const String _eventSlugKey = 'selected_event_slug';

  Future<void> _loadSelectedEvent() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_eventIdKey);
    final name = prefs.getString(_eventNameKey);
    final slug = prefs.getString(_eventSlugKey);
    
    if (id != null && name != null && slug != null) {
      state = {'id': id, 'name': name, 'slug': slug};
    }
  }

  Future<void> selectEvent(String id, String name, String slug) async {
    state = {'id': id, 'name': name, 'slug': slug};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventIdKey, id);
    await prefs.setString(_eventNameKey, name);
    await prefs.setString(_eventSlugKey, slug);
  }

  Future<void> clearEvent() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventIdKey);
    await prefs.remove(_eventNameKey);
    await prefs.remove(_eventSlugKey);
  }
  Future<void> validate(List<Map<String, dynamic>> availableEvents) async {
    if (state == null) return;
    final exists = availableEvents.any((e) => e['id'] == state!['id']);
    if (!exists) {
      await clearEvent();
    }
  }
}

final selectedEventProvider = StateNotifierProvider<SelectedEventNotifier, Map<String, dynamic>?>((ref) {
  return SelectedEventNotifier();
});
