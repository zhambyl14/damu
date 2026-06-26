// lib/services/notification_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Stream user's notifications using Supabase realtime.
  Stream<List<AppNotification>> watch(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((list) {
      return (list as List)
          .map((d) => AppNotification.fromMap(d as Map<String, dynamic>, d['id'].toString()))
          .toList();
    });
  }

  Future<void> send({
    required String userId,
    required String title,
    required String body,
    String type = 'system',
  }) async {
    await _supabase.from('notifications').insert([
      {
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      }
    ]);
  }

  Future<void> markRead(String id) async {
    await _supabase.from('notifications').update({'read': true}).eq('id', id);
  }

  Future<void> markAllRead(String userId) async {
    await _supabase.from('notifications').update({'read': true}).eq('user_id', userId).eq('read', false);
  }

  Future<void> delete(String id) async {
    await _supabase.from('notifications').delete().eq('id', id);
  }
}
