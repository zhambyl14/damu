// lib/services/video_progress_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class VideoProgressService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Mark a topic as watched for a user. Uses upsert to avoid duplicates.
  Future<void> markWatched(String uid, String subjectId, String topicId) async {
    // supabase_flutter v2: қате болса exception лақтырады (res.error жоқ).
    await _supabase.from('video_progress').upsert(
      {
        'user_id': uid,
        'subject_id': subjectId,
        'topic_id': topicId,
        'watched_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,subject_id,topic_id',
    );
  }

  /// Returns a stream of watched keys like 'subject_topic'
  Stream<Set<String>> watchProgress(String uid) {
    return _supabase
        .from('video_progress')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map((list) {
      return (list as List)
          .map((d) {
            final subject = d['subject_id'] as String?;
            final topic = d['topic_id'] as String?;
            if (subject == null || topic == null) return null;
            return '${subject}_$topic';
          })
          .whereType<String>()
          .toSet();
    });
  }
}
