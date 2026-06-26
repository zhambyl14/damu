// lib/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseManager {
  /// Initialize Supabase. For production set values via --dart-define
  /// e.g. flutter run --dart-define=SUPABASE_URL=https://... \
  /// --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
  static Future<void> init() async {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://ldgorlayfkskxqbtttry.supabase.co',
    );
    const publishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_F3FkV9catPjwwa8KJkjYXg_YJN9xhsE',
    );

    await Supabase.initialize(
      url: url,
      // Жаңа формат кілт (sb_publishable_...) — anonKey емес, publishableKey
      publishableKey: publishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
