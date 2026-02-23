import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:imagine_access/core/config/env.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  group('Env', () {
    test('supabaseUrl should return a valid URL', () {
      final url = Env.supabaseUrl;
      expect(url, isNotNull);
      expect(url, isNotEmpty);
      expect(url.startsWith('https://'), isTrue);
    });

    test('supabaseAnonKey should return a valid key', () {
      final key = Env.supabaseAnonKey;
      expect(key, isNotNull);
      expect(key, isNotEmpty);
      expect(key.length, greaterThan(20));
    });
  });
}
