// lib/services/content_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topic_model.dart';
import '../models/question_model.dart';
import '../models/flashcard_model.dart';

/// subjects/topics/questions/flashcards mapped to Postgres tables.
class ContentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── ТАҚЫРЫПТАР ───────────────────────────────────────────
  Stream<List<TopicModel>> watchTopics(String subjectId) {
    return _supabase
        .from('topics')
        .stream(primaryKey: ['id'])
        .eq('subject_id', subjectId)
        .order('order', ascending: true)
        .map((list) => (list as List)
            .map((d) => TopicModel.fromMap(d as Map<String, dynamic>, d['id'].toString(), subjectId))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)));
  }

  Future<List<TopicModel>> getTopics(String subjectId) async {
    final res = await _supabase.from('topics').select().eq('subject_id', subjectId).order('order', ascending: true);
    final list = (res as List)
        .map((d) => TopicModel.fromMap(d as Map<String, dynamic>, d['id'].toString(), subjectId))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  Future<String> addTopic({
    required String subjectId,
    required String title,
    String? videoUrl,
    String? createdBy,
  }) async {
    final existing = await _supabase.from('topics').select('id').eq('subject_id', subjectId);
    final order = (existing as List).length;
    final payload = {
      'title': title,
      'order': order,
      'question_count': 0,
      'flashcard_count': 0,
      'video_url': videoUrl,
      'subject_id': subjectId,
      if (createdBy != null) 'created_by': createdBy,
    };
    final res = await _supabase.from('topics').insert(payload).select().maybeSingle();
    if (res == null) throw Exception('Insert failed');
    return res['id'].toString();
  }

  Future<void> updateTopic({
    required String subjectId,
    required String topicId,
    required String title,
    String? videoUrl,
  }) async {
    await _supabase.from('topics').update({'title': title, 'video_url': videoUrl}).eq('id', topicId);
  }

  /// Тақырыпты және оның барлық сұрақтары мен флешкарталарын өшіру.
  Future<void> deleteTopic(String subjectId, String topicId) async {
    await _supabase.from('questions').delete().eq('topic_id', topicId);
    await _supabase.from('flashcards').delete().eq('topic_id', topicId);
    await _supabase.from('topics').delete().eq('id', topicId);
  }

  // ── СҰРАҚТАР ─────────────────────────────────────────────
  Stream<List<QuestionModel>> watchQuestions(String subjectId, String topicId) {
    return _supabase
        .from('questions')
        .stream(primaryKey: ['id'])
        .eq('topic_id', topicId)
        .order('order', ascending: true)
        .map((list) => (list as List)
            .map((d) => QuestionModel.fromMap(d as Map<String, dynamic>, d['id'].toString(), subjectId: subjectId, topicId: topicId))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)));
  }

  Future<List<QuestionModel>> getQuestions(String subjectId, String topicId) async {
    final res = await _supabase.from('questions').select().eq('topic_id', topicId).order('order', ascending: true);
    return (res as List)
        .map((d) => QuestionModel.fromMap(d as Map<String, dynamic>, d['id'].toString(), subjectId: subjectId, topicId: topicId))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> addQuestion(QuestionModel q) async {
    // order — соңына қосу (millisecondsSinceEpoch int4-тен асып кетеді, 22003).
    final list =
        await _supabase.from('questions').select('id').eq('topic_id', q.topicId);
    final count = (list as List).length;
    final map = q.toMap();
    map['order'] = count;
    await _supabase.from('questions').insert(map);
    await _supabase
        .from('topics')
        .update({'question_count': count + 1}).eq('id', q.topicId);
  }

  /// Бірнеше сұрақты бір рет жазу (PDF/мәтіннен жаппай импорт).
  /// `order` тақырыптағы бар сұрақтар санынан бастап беріледі. Жазылған санды қайтарады.
  Future<int> bulkAddQuestions(List<QuestionModel> questions,
      {required String topicId}) async {
    if (questions.isEmpty) return 0;
    final existing =
        await _supabase.from('questions').select('id').eq('topic_id', topicId);
    final base = (existing as List).length;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < questions.length; i++) {
      final m = questions[i].toMap();
      m['order'] = base + i;
      rows.add(m);
    }
    await _supabase.from('questions').insert(rows);
    await _supabase
        .from('topics')
        .update({'question_count': base + rows.length}).eq('id', topicId);
    return rows.length;
  }

  Future<void> updateQuestion(QuestionModel q) async {
    await _supabase.from('questions').update(q.toMap()).eq('id', q.id);
  }

  Future<void> deleteQuestion(QuestionModel q) async {
    await _supabase.from('questions').delete().eq('id', q.id);
    final list = await _supabase.from('questions').select('id').eq('topic_id', q.topicId);
    final count = (list as List).length;
    await _supabase.from('topics').update({'question_count': count}).eq('id', q.topicId);
  }

  // ── ФЛЕШКАРТАЛАР ─────────────────────────────────────────
  Stream<List<FlashcardModel>> watchFlashcards(String subjectId, String topicId) {
    return _supabase
        .from('flashcards')
        .stream(primaryKey: ['id'])
        .eq('topic_id', topicId)
        .order('order', ascending: true)
        .map((list) => (list as List)
            .map((d) => FlashcardModel.fromMap(d as Map<String, dynamic>, d['id'].toString(), subjectId: subjectId, topicId: topicId))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)));
  }

  Future<List<FlashcardModel>> getFlashcards(String subjectId, String topicId) async {
    final res = await _supabase.from('flashcards').select().eq('topic_id', topicId).order('order', ascending: true);
    return (res as List)
        .map((d) => FlashcardModel.fromMap(d as Map<String, dynamic>, d['id'].toString(), subjectId: subjectId, topicId: topicId))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> addFlashcard(FlashcardModel f) async {
    // order — соңына қосу (millisecondsSinceEpoch int4-тен асып кетеді, 22003).
    final list = await _supabase
        .from('flashcards')
        .select('id')
        .eq('topic_id', f.topicId);
    final count = (list as List).length;
    final map = f.toMap();
    map['order'] = count;
    await _supabase.from('flashcards').insert(map);
    await _supabase
        .from('topics')
        .update({'flashcard_count': count + 1}).eq('id', f.topicId);
  }

  /// Бірнеше флешкартаны бір рет жазу (жаппай импорт). Жазылған санды қайтарады.
  Future<int> bulkAddFlashcards(List<FlashcardModel> cards,
      {required String topicId}) async {
    if (cards.isEmpty) return 0;
    final existing =
        await _supabase.from('flashcards').select('id').eq('topic_id', topicId);
    final base = (existing as List).length;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < cards.length; i++) {
      final m = cards[i].toMap();
      m['order'] = base + i;
      rows.add(m);
    }
    await _supabase.from('flashcards').insert(rows);
    await _supabase
        .from('topics')
        .update({'flashcard_count': base + rows.length}).eq('id', topicId);
    return rows.length;
  }

  Future<void> updateFlashcard(FlashcardModel f) async {
    await _supabase.from('flashcards').update(f.toMap()).eq('id', f.id);
  }

  Future<void> deleteFlashcard(FlashcardModel f) async {
    await _supabase.from('flashcards').delete().eq('id', f.id);
    final list = await _supabase.from('flashcards').select('id').eq('topic_id', f.topicId);
    final count = (list as List).length;
    await _supabase.from('topics').update({'flashcard_count': count}).eq('id', f.topicId);
  }

  // ── ОҚУШЫ ТЕСТ ТАПСЫРҒАНДА ───────────────────────────────
  Future<void> saveQuizAttempt({
    required String studentId,
    required String studentName,
    required String subjectId,
    required String topicId,
    required String topicTitle,
    required int correct,
    required int total,
  }) async {
    await _supabase.from('quizattempts').insert({
      'student_id': studentId,
      'student_name': studentName,
      'subject_id': subjectId,
      'topic_id': topicId,
      'topic_title': topicTitle,
      'correct': correct,
      'total': total,
      'percent': total > 0 ? ((correct / total) * 100).round() : 0,
    });
  }

  Stream<List<Map<String, dynamic>>> watchStudentAttempts(String studentId) {
    return _supabase
        .from('quizattempts')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .map((list) => (list as List).map((d) {
              final m = Map<String, dynamic>.from(d as Map<String, dynamic>);
              m['id'] = m['id'].toString();
              return m;
            }).toList());
  }
}
