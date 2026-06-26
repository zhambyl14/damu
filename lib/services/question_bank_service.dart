// lib/services/question_bank_service.dart
//
// Сұрақтар банкі + ҰБТ тест генерациясы.
//
//   • Админ банкті толтырады (addQuestion / bulkAddQuestions).
//   • Тест ашылғанда generateUntTest() банктен толық ҰБТ структурасы бойынша
//     әр оқушыға жеке кездейсоқ нұсқа жинайды — бұрын КӨРГЕН сұрақтарды
//     мүмкіндігінше қоспай (барлық тапсыруда қайталанбау).
//   • Тест аяқталғанда markSeen() көрген сұрақтарды белгілейді.

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mock_test_model.dart';
import '../models/user_model.dart';
import '../data/unt_structure.dart';

/// Генерация нәтижесі: реттелген сұрақтар + балл бойынша қысқаша мәлімет.
class GeneratedTest {
  final List<MockQuestion> questions;

  /// Әр пәннің/бөлімнің іс жүзінде жиналған сұрақ саны мен макс. баллы.
  /// (банк толық болмаса, талаптан аз болуы мүмкін — UI ескертеді).
  final Map<String, int> filledCount;
  final Map<String, int> filledMaxPoints;

  const GeneratedTest({
    required this.questions,
    required this.filledCount,
    required this.filledMaxPoints,
  });

  bool get isEmpty => questions.isEmpty;
  int get totalQuestions => questions.length;
  int get totalMaxPoints =>
      filledMaxPoints.values.fold(0, (s, v) => s + v);
}

class QuestionBankService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _rng = Random();

  // ── БАНКТІ БАСҚАРУ (админ) ──────────────────────────────────────────────
  Stream<List<MockQuestion>> watchBank() {
    return _supabase.from('question_bank').stream(primaryKey: ['id']).map(
        (list) => (list as List)
            .map((d) => MockQuestion.fromMap(
                d as Map<String, dynamic>, d['id'].toString(), ''))
            .toList());
  }

  Future<List<MockQuestion>> getBank({String? section, String? subjectId}) async {
    var query = _supabase.from('question_bank').select().eq('active', true);
    if (section != null) query = query.eq('section', section);
    if (subjectId != null) query = query.eq('subject_id', subjectId);
    final res = await query;
    return (res as List)
        .map((d) => MockQuestion.fromMap(
            d as Map<String, dynamic>, d['id'].toString(), ''))
        .toList();
  }

  /// Бөлім/пән/балл бойынша банкте қанша сұрақ бар (админге толықтығын көрсету).
  Future<Map<String, int>> bankCounts() async {
    final res = await _supabase
        .from('question_bank')
        .select('section, subject_id, points')
        .eq('active', true);
    final counts = <String, int>{};
    for (final row in (res as List)) {
      final m = row as Map<String, dynamic>;
      final key = _bucketKey(
          m['section'] as String? ?? '',
          m['subject_id'] as String?,
          (m['points'] as num?)?.toInt() ?? 1);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> addQuestion(MockQuestion q, {String? createdBy}) async {
    final map = q.toBankMap();
    if (createdBy != null) map['created_by'] = createdBy;
    await _supabase.from('question_bank').insert(map);
  }

  Future<int> bulkAddQuestions(List<MockQuestion> questions,
      {String? createdBy}) async {
    if (questions.isEmpty) return 0;
    final rows = questions.map((q) {
      final m = q.toBankMap();
      if (createdBy != null) m['created_by'] = createdBy;
      return m;
    }).toList();
    await _supabase.from('question_bank').insert(rows);
    return rows.length;
  }

  Future<void> updateQuestion(MockQuestion q) async {
    await _supabase.from('question_bank').update(q.toBankMap()).eq('id', q.id);
  }

  Future<void> deleteQuestion(String id) async {
    await _supabase.from('question_bank').delete().eq('id', id);
  }

  // ── ГЕНЕРАЦИЯ ───────────────────────────────────────────────────────────

  /// Оқушы бұрын көрген банк сұрақтарының id-лері.
  Future<Set<String>> _seenIds(String studentId) async {
    final res = await _supabase
        .from('student_seen_questions')
        .select('question_id')
        .eq('student_id', studentId);
    return {for (final r in (res as List)) (r['question_id']).toString()};
  }

  /// Бір шелектен (бөлім+пән+балл) `count` сұрақ таңдау.
  /// Алдымен көрілмегендерден, жетпесе көргендерден толтырады.
  List<Map<String, dynamic>> _pick(
      List<Map<String, dynamic>> rows, int count, Set<String> seen) {
    final unseen = <Map<String, dynamic>>[];
    final seenRows = <Map<String, dynamic>>[];
    for (final r in rows) {
      (seen.contains(r['id'].toString()) ? seenRows : unseen).add(r);
    }
    unseen.shuffle(_rng);
    seenRows.shuffle(_rng);
    final picked = <Map<String, dynamic>>[];
    picked.addAll(unseen.take(count));
    if (picked.length < count) {
      picked.addAll(seenRows.take(count - picked.length));
    }
    return picked;
  }

  /// Толық ҰБТ тестін генерациялау (per-student). [mockId] — нәтиже сұрақтарының
  /// mockId өрісіне жазылады (айлық мокта — нақты id, дайындықта — 'practice').
  Future<GeneratedTest> generateUntTest(UserModel student,
      {String mockId = ''}) async {
    final seen = await _seenIds(student.uid);

    // Барлық белсенді банк сұрағын бір рет алып, жадыда сүземіз.
    final res = await _supabase.from('question_bank').select().eq('active', true);
    final all = (res as List).cast<Map<String, dynamic>>();

    final byBucket = <String, List<Map<String, dynamic>>>{};
    for (final r in all) {
      final key = _bucketKey(
          r['section'] as String? ?? '',
          r['subject_id'] as String?,
          (r['points'] as num?)?.toInt() ?? 1);
      (byBucket[key] ??= []).add(r);
    }

    final picked = <Map<String, dynamic>>[];
    final filledCount = <String, int>{};
    final filledMax = <String, int>{};

    void take(String section, String? subjectId, List<UntTier> tiers) {
      final bucketLabel = subjectId ?? section;
      for (final tier in tiers) {
        final key = _bucketKey(section, subjectId, tier.points);
        final rows = byBucket[key] ?? const [];
        final chosen = _pick(List.of(rows), tier.count, seen);
        picked.addAll(chosen);
        filledCount[bucketLabel] = (filledCount[bucketLabel] ?? 0) + chosen.length;
        filledMax[bucketLabel] =
            (filledMax[bucketLabel] ?? 0) + chosen.length * tier.points;
      }
    }

    // 1) Міндетті бөлімдер.
    for (final spec in UntStructure.mandatory) {
      take(spec.section, null, spec.tiers);
    }
    // 2) Оқушының 2 бейіндік пәні.
    for (final subjId in student.electiveSubjectIds) {
      take(MockSection.elective, subjId, UntStructure.profileTiers);
    }

    // Реттік нөмір беріп, MockQuestion-ға айналдыру.
    final questions = <MockQuestion>[];
    for (var i = 0; i < picked.length; i++) {
      final r = Map<String, dynamic>.from(picked[i]);
      r['order'] = i;
      questions.add(MockQuestion.fromMap(r, r['id'].toString(), mockId));
    }

    return GeneratedTest(
      questions: questions,
      filledCount: filledCount,
      filledMaxPoints: filledMax,
    );
  }

  /// Сақталған draft-ты қалпына келтіру: банктен берілген id-лер бойынша
  /// сұрақтарды алып, СОЛ РЕТПЕН қайтарады (order = сақталған реті).
  /// Бір сұрақ жоқ болса (өшірілген) — ол қалдырылады; шақырушы ұзындықты
  /// тексеріп, сәйкессіздікте жаңадан генерациялайды.
  Future<List<MockQuestion>> fetchByIds(List<String> ids, String mockId) async {
    if (ids.isEmpty) return [];
    final res =
        await _supabase.from('question_bank').select().inFilter('id', ids);
    final byId = <String, Map<String, dynamic>>{
      for (final r in (res as List))
        (r as Map<String, dynamic>)['id'].toString(): r
    };
    final out = <MockQuestion>[];
    for (var i = 0; i < ids.length; i++) {
      final r = byId[ids[i]];
      if (r == null) continue; // өшірілген сұрақ — өткізіп жібереміз
      final m = Map<String, dynamic>.from(r);
      m['order'] = i;
      out.add(MockQuestion.fromMap(m, ids[i], mockId));
    }
    return out;
  }

  /// Тест аяқталғанда көрген сұрақтарды белгілеу (қайталанбауы үшін).
  Future<void> markSeen(String studentId, List<String> questionIds) async {
    if (questionIds.isEmpty) return;
    final rows = questionIds
        .toSet()
        .map((id) => {'student_id': studentId, 'question_id': id})
        .toList();
    // Бұрын белгіленгендер болса — елемейді (upsert, PK student+question).
    await _supabase
        .from('student_seen_questions')
        .upsert(rows, onConflict: 'student_id,question_id', ignoreDuplicates: true);
  }

  static String _bucketKey(String section, String? subjectId, int points) =>
      section == MockSection.elective
          ? 'elective:${subjectId ?? ''}:$points'
          : '$section:$points';
}
