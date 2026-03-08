import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl {
    final fromEnvFile = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    const fromDartDefine = String.fromEnvironment('SUPABASE_URL');
    final value = fromEnvFile.isNotEmpty ? fromEnvFile : fromDartDefine.trim();

    if (value.isEmpty) {
      throw Exception(
        'SUPABASE_URL not found. Set it in .env or pass --dart-define=SUPABASE_URL=...',
      );
    }

    if (value.contains('your-project.supabase.co') ||
        value.contains('tu-proyecto.supabase.co')) {
      throw Exception(
        'SUPABASE_URL contains a placeholder value. Replace it with your real Supabase project URL.',
      );
    }

    return value;
  }

  static String get supabaseAnonKey {
    final fromEnvFile = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    const fromDartDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
    final value = fromEnvFile.isNotEmpty ? fromEnvFile : fromDartDefine.trim();

    if (value.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY not found. Set it in .env or pass --dart-define=SUPABASE_ANON_KEY=...',
      );
    }

    if (value.contains('your-anon-key') || value.contains('tu-anon-key')) {
      throw Exception(
        'SUPABASE_ANON_KEY contains a placeholder value. Replace it with your real anon key.',
      );
    }

    if (value.length < 20) {
      throw Exception('SUPABASE_ANON_KEY looks invalid (too short).');
    }

    return value;
  }
}
