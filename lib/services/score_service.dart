import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/score_model.dart';

class ScoreService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Оқушы: тек өзінің баллдарын Firestore-дан Stream арқылы алу ─────────────────────────
  Stream<List<ScoreModel>> watchStudentScores(String studentId) {
    return _supabase
        .from('scores')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .order('date', ascending: true)
        .map((list) => (list as List)
            .map((d) => ScoreModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
            .toList());
  }

  // ── Куратор: тек өзіне бекітілген оқушылардың баллдарын алу ──────────
  Stream<List<ScoreModel>> watchCuratorScores(String curatorId) {
    return _supabase
        .from('scores')
        .stream(primaryKey: ['id'])
        .eq('curator_id', curatorId)
        .order('date', ascending: true)
        .map((list) => (list as List)
            .map((d) => ScoreModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
            .toList());
  }

  // ── Директор/Админ: мектептегі барлық 90 оқушының баллдарын алу ────────────────────────
  Stream<List<ScoreModel>> watchAllScores() {
    return _supabase
        .from('scores')
        .stream(primaryKey: ['id'])
        .order('date', ascending: true)
        .map((list) => (list as List)
            .map((d) => ScoreModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
            .toList());
  }

  // ── Жаңа балл қосу (Куратор/Админ қолмен енгізгенде) ───────────────────────
  Future<String> addScore(ScoreModel score) async {
    final res = await _supabase.from('scores').insert(score.toMap()).select().maybeSingle();
    if (res == null) throw Exception('Insert failed');
    return (res['id']).toString();
  }

  // ── Тест жазбасын толық жаңарту (метадеректермен бірге) ──────────
  Future<void> updateScoreModel(ScoreModel score) async {
    await _supabase.from('scores').update(score.toMap()).eq('id', score.id);
  }

  // ── Баллды жаңарту / Түзету (5 пән бойынша) ────────────────────
  Future<void> updateScore({
    required String id,
    required int kazakhHistory,
    required int readingLiteracy,
    required int mathLiteracy,
    required int elective1,
    required int elective2,
  }) async {
    final int total = kazakhHistory + readingLiteracy + mathLiteracy + elective1 + elective2;
    
    await _supabase.from('scores').update({
      'kazakh_history': kazakhHistory,
      'reading_literacy': readingLiteracy,
      'math_literacy': mathLiteracy,
      'elective1': elective1,
      'elective2': elective2,
      'total_score': total,
      'mandatory_score': kazakhHistory + readingLiteracy + mathLiteracy,
      'elective_score': elective1 + elective2,
    }).eq('id', id);
  }

  // ── Баллды өшіру ────────────────────────────────────
  Future<void> deleteScore(String id) async {
    await _supabase.from('scores').delete().eq('id', id);
  }

  // ── Оқушының ең соңғы тапсырған тестін анықтау ─────────────────
  static Map<String, ScoreModel> latestPerStudent(List<ScoreModel> scores) {
    final Map<String, ScoreModel> result = {};
    for (final s in scores) {
      final existing = result[s.studentId];
      if (existing == null || s.date.isAfter(existing.date)) {
        result[s.studentId] = s;
      }
    }
    return result;
  }

  // ── Нақты оқушылардың орташа балын есептеу ─────────────────────
  static double average(List<ScoreModel> scores) {
    if (scores.isEmpty) return 0.0;
    final int totalSum = scores.fold<int>(0, (acc, s) => acc + s.totalScore);
    return totalSum / scores.length;
  }

  // ── Тізім ішінен белгілі бір оқушыны сүзіп алу ────────────
  static List<ScoreModel> forStudent(List<ScoreModel> all, String studentId) =>
      all.where((s) => s.studentId == studentId).toList();
}