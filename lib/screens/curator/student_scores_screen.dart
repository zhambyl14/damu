// lib/screens/curator/student_scores_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../models/score_model.dart';
import '../../services/score_service.dart';
import 'add_edit_score_screen.dart';

/// Куратор бір оқушының барлық тест нәтижелерін көреді әрі басқарады.
class StudentScoresScreen extends StatelessWidget {
  final UserModel curator;
  final UserModel student;

  const StudentScoresScreen({
    super.key,
    required this.curator,
    required this.student,
  });

  static const _months = [
    'Қаңтар', 'Ақпан', 'Наурыз', 'Сәуір', 'Мамыр', 'Маусым',
    'Шілде', 'Тамыз', 'Қыркүйек', 'Қазан', 'Қараша', 'Желтоқсан'
  ];

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(student.name),
        backgroundColor: AppColors.navyBlue,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDark,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Тест қосу'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditScoreScreen(
              curator: curator,
              student: student,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: Supabase.instance.client
            .from('scores')
            .stream(primaryKey: ['id'])
            .eq('student_id', student.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }

          final scores = (snap.data ?? [])
              .map((d) => ScoreModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          if (scores.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined,
                      color: AppColors.textMuted, size: 56),
                  const SizedBox(height: 12),
                  Text('Тест нәтижелері жоқ',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Text('"Тест қосу" батырмасын басыңыз',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }

          final avg = scores.fold<int>(0, (s, e) => s + e.totalScore) /
              scores.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              _summaryCard(context, scores.length, avg, scores.first),
              const SizedBox(height: 20),
              Text('Барлық сынақтар',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.navyBlue, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...scores.map((s) => _scoreCard(context, s)),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(
      BuildContext context, int count, double avg, ScoreModel latest) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDark, AppColors.navyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _miniStat('Сынақтар', '$count', AppColors.white),
          ),
          Container(width: 1, height: 36, color: AppColors.white.withValues(alpha: 0.15)),
          Expanded(
            child: _miniStat('Орташа', avg.toStringAsFixed(1), AppColors.gold),
          ),
          Container(width: 1, height: 36, color: AppColors.white.withValues(alpha: 0.15)),
          Expanded(
            child:
                _miniStat('Соңғы', '${latest.totalScore}', AppColors.goldLight),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.6), fontSize: 12)),
        ],
      );

  Widget _scoreCard(BuildContext context, ScoreModel s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: s.scoreColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text('${s.totalScore}',
                    style: TextStyle(
                        color: s.scoreColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
            title: Text(s.testName ?? 'ҰБТ сынағы',
                style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text('${_fmt(s.date)} · ${s.scoreGrade}',
                style: Theme.of(context).textTheme.bodySmall),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textMuted),
              onSelected: (v) {
                if (v == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditScoreScreen(
                        curator: curator,
                        student: student,
                        existing: s,
                      ),
                    ),
                  );
                } else if (v == 'delete') {
                  _confirmDelete(context, s);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_rounded,
                        size: 18, color: AppColors.navyBlue),
                    SizedBox(width: 10),
                    Text('Түзету'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.error),
                    SizedBox(width: 10),
                    Text('Өшіру'),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip('Тарих ${s.kazakhHistory}/20'),
                _chip('Оқу ${s.readingLiteracy}/20'),
                _chip('Матем. ${s.mathLiteracy}/20'),
                _chip('${s.elective1Name ?? "Таңдау 1"} ${s.elective1}/40'),
                _chip('${s.elective2Name ?? "Таңдау 2"} ${s.elective2}/40'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      );

  Future<void> _confirmDelete(BuildContext context, ScoreModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Нәтижені өшіру'),
        content: Text(
            '"${s.testName ?? "ҰБТ сынағы"}" нәтижесін өшіргіңіз келе ме?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Болдырмау')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Өшіру'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ScoreService().deleteScore(s.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Нәтиже өшірілді'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
