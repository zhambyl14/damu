// lib/services/mock_test_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mock_test_model.dart';

class MockTestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── МОК ТЕСТТЕР ──────────────────────────────────────────
  Stream<List<MockTest>> watchActive() {
    return _supabase
        .from('mocktests')
        .stream(primaryKey: ['id'])
        .eq('active', true)
        .map((list) => (list as List)
            .map((d) => MockTest.fromMap(d as Map<String, dynamic>, d['id'].toString()))
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2000))
              .compareTo(a.createdAt ?? DateTime(2000))));
  }

  Stream<List<MockTest>> watchAll() {
    return _supabase.from('mocktests').stream(primaryKey: ['id']).map((list) =>
        (list as List)
            .map((d) => MockTest.fromMap(d as Map<String, dynamic>, d['id'].toString()))
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2000))
              .compareTo(a.createdAt ?? DateTime(2000))));
  }

  Future<String> addMock(MockTest mock) async {
    final res = await _supabase.from('mocktests').insert(mock.toMap()).select().maybeSingle();
    if (res == null) throw Exception('Insert failed');
    return res['id'].toString();
  }

  Future<void> updateMock(String id, Map<String, dynamic> data) async {
    await _supabase.from('mocktests').update(data).eq('id', id);
  }

  Future<void> deleteMock(String id) async {
    await _supabase.from('mock_questions').delete().eq('mock_id', id);
    await _supabase.from('mocktests').delete().eq('id', id);
  }

  // ── СҰРАҚТАР ─────────────────────────────────────────────
  Stream<List<MockQuestion>> watchQuestions(String mockId) {
    return _supabase
        .from('mock_questions')
        .stream(primaryKey: ['id'])
        .eq('mock_id', mockId)
        .map((list) => (list as List)
            .map((d) => MockQuestion.fromMap(d as Map<String, dynamic>, d['id'].toString(), mockId))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)));
  }

  Future<List<MockQuestion>> getQuestions(String mockId) async {
    final res = await _supabase.from('mock_questions').select().eq('mock_id', mockId).order('order', ascending: true);
    return (res as List)
        .map((d) => MockQuestion.fromMap(d as Map<String, dynamic>, d['id'].toString(), mockId))
        .toList();
  }

  Future<void> addQuestion(MockQuestion q) async {
    // order — соңына қосу (millisecondsSinceEpoch int4-тен асып кетеді, 22003).
    final existing =
        await _supabase.from('mock_questions').select('id').eq('mock_id', q.mockId);
    final base = (existing as List).length;
    final map = q.toMap();
    map['order'] = base; // қауіпсіз кіші сан
    await _supabase.from('mock_questions').insert(map);
    await _supabase
        .from('mocktests')
        .update({'question_count': base + 1}).eq('id', q.mockId);
  }

  /// Бірнеше сұрақты бір рет жазу (PDF/мәтіннен жаппай импорт).
  /// `order` бар сұрақтардың санынан бастап автоматты беріледі.
  /// Жазылған сұрақтар санын қайтарады.
  Future<int> bulkAddQuestions(List<MockQuestion> questions,
      {required String mockId}) async {
    if (questions.isEmpty) return 0;
    final existing =
        await _supabase.from('mock_questions').select('id').eq('mock_id', mockId);
    final base = (existing as List).length;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < questions.length; i++) {
      final m = questions[i].toMap();
      m['order'] = base + i;
      rows.add(m);
    }
    await _supabase.from('mock_questions').insert(rows);
    await _supabase
        .from('mocktests')
        .update({'question_count': base + rows.length}).eq('id', mockId);
    return rows.length;
  }

  Future<void> updateQuestion(MockQuestion q) async {
    await _supabase.from('mock_questions').update(q.toMap()).eq('id', q.id);
  }

  Future<void> deleteQuestion(MockQuestion q) async {
    await _supabase.from('mock_questions').delete().eq('id', q.id);
    final list = await _supabase.from('mock_questions').select('id').eq('mock_id', q.mockId);
    final count = (list as List).length;
    await _supabase.from('mocktests').update({'question_count': count}).eq('id', q.mockId);
  }
}
