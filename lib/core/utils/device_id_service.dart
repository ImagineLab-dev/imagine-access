import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final deviceIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString('device_uuid');
  
  if (deviceId == null) {
    deviceId = _generateUuid();
    await prefs.setString('device_uuid', deviceId);
  }
  return deviceId;
});

// Simple V4-like UUID generator
String _generateUuid() {
  final random = Random();
  
  String hex(int length) {
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(random.nextInt(16).toRadixString(16));
    }
    return sb.toString();
  }

  // xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  return '${hex(8)}-${hex(4)}-4${hex(3)}-${(random.nextInt(4) + 8).toRadixString(16)}${hex(3)}-${hex(12)}';
}
