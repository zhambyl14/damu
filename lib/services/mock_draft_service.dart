// lib/services/mock_draft_service.dart
//
// Аяқталмаған ҰБТ/дайындық тестін авто-сақтау (test_drafts кестесі).
//   • save()  — жауап/flag/навигация өзгерген сайын debounce-пен жазылады.
//   • load()  — экран ашылғанда draft бар-жоғын тексереді.
//   • clear() — тест аяқталғанда (тапсырылғанда) өшіріледі.
//
// Әр оқушыда (student_id) әр тестке (mock_id немесе 'practice') бір ғана draft.

import 'package:supabase_flutter/supabase_flutter.dart';

class MockDraftService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Сақталған draft-ты жүктеу. Болмаса — null.
  Future<Map<String, dynamic>?> load(String studentId, String mockKey) async {
    final res = await _supabase
        .from('test_drafts')
        .select()
        .eq('student_id', studentId)
        .eq('mock_id', mockKey)
        .maybeSingle();
    return res;
  }

  /// Ағымдағы прогресті сақтау (upsert — бар болса жаңартады).
  Future<void> save({
    required String studentId,
    required String mockKey,
    required List<String> questionIds,
    required Map<int, Set<int>> answers,
    required Set<int> flagged,
    required int remainingSeconds,
    required int currentIndex,
  }) async {
    final answersJson = <String, List<int>>{
      for (final e in answers.entries)
        if (e.value.isNotEmpty) e.key.toString(): e.value.toList(),
    };
    await _supabase.from('test_drafts').upsert({
      'student_id': studentId,
      'mock_id': mockKey,
      'question_ids': questionIds,
      'answers': answersJson,
      'flagged': flagged.toList(),
      'remaining_seconds': remainingSeconds,
      'current_index': currentIndex,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'student_id,mock_id');
  }

  /// Тест тапсырылғанда draft-ты өшіру (қайта жалғастыру болмауы үшін).
  Future<void> clear(String studentId, String mockKey) async {
    await _supabase
        .from('test_drafts')
        .delete()
        .eq('student_id', studentId)
        .eq('mock_id', mockKey);
  }
}
