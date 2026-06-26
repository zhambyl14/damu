// lib/screens/curator/curator_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../models/score_model.dart';
import '../../providers/auth_provider.dart';
import 'add_edit_score_screen.dart';
import 'student_scores_screen.dart';

class CuratorDashboardScreen extends StatefulWidget {
  const CuratorDashboardScreen({super.key});

  @override
  State<CuratorDashboardScreen> createState() =>
      _CuratorDashboardScreenState();
}

class _CuratorDashboardScreenState extends State<CuratorDashboardScreen> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Шығуды растау'),
        content: const Text('Сіз шынымен жүйеден шыққыңыз келе ме?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болдырмау'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Шығу'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final curator = context.watch<AuthProvider>().userModel;
    if (curator == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('curator_id', curator.uid),
      builder: (context, studentSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('scores')
              .stream(primaryKey: ['id'])
              .eq('curator_id', curator.uid),
          builder: (context, scoreSnap) {
            // role == 'student' сүзгісін клиент жағында жасаймыз
            final studentDocs = (studentSnap.data ?? [])
                .where((m) => m['role'] == 'student')
                .toList();
            final scoreDocs = scoreSnap.data ?? [];

            // Барлық баллдарды парс ету
            final allScores = scoreDocs
                .map((d) => ScoreModel.fromMap(d, d['id'].toString()))
                .toList();

            // Әр оқушының соңғы баллы
            final Map<String, ScoreModel> latestPerStudent = {};
            for (final s in allScores) {
              final cur = latestPerStudent[s.studentId];
              if (cur == null || s.date.isAfter(cur.date)) {
                latestPerStudent[s.studentId] = s;
              }
            }

            // ── Сынып орташасы (соңғы балл бойынша) ──
            final latestList = latestPerStudent.values.toList();
            double classAvg = 0;
            int passCount = 0;
            int topScore = 0;
            if (latestList.isNotEmpty) {
              final total =
                  latestList.fold<int>(0, (s, m) => s + m.totalScore);
              classAvg = total / latestList.length;
              passCount =
                  latestList.where((m) => m.totalScore >= 90).length;
              topScore = latestList
                  .map((m) => m.totalScore)
                  .reduce((a, b) => a > b ? a : b);
            }

            // ── Пәндік статистика — барлық тесттер бойынша орташа ──
            final subjectAvg = _calcSubjectAvg(allScores);

            // Сүзу
            final filtered = studentDocs.where((data) {
              final name =
                  (data['name'] as String? ?? '').toLowerCase();
              return _searchQuery.isEmpty ||
                  name.contains(_searchQuery.toLowerCase());
            }).toList();

            return Scaffold(
              backgroundColor: AppColors.background,
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navyDark,
                icon: const Icon(Icons.add_chart_rounded),
                label: const Text('Тест қосу'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditScoreScreen(curator: curator),
                  ),
                ),
              ),
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: AppColors.navyBlue,
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.logout_rounded,
                            color: AppColors.gold),
                        tooltip: 'Шығу',
                        onPressed: _confirmSignOut,
                      ),
                      const SizedBox(width: 4),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: _CuratorHero(
                        curator: curator,
                        classAvg: classAvg,
                        studentCount: studentDocs.length,
                      ),
                    ),
                    title: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.school_rounded,
                                color: AppColors.navyBlue,
                                size: 24),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Куратор панелі',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppColors.white),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _KpiCard(
                                label: 'Орташа балл',
                                value: classAvg.toStringAsFixed(1),
                                icon: Icons.bar_chart_rounded,
                                color: AppColors.navyBlue,
                              ),
                              const SizedBox(width: 10),
                              _KpiCard(
                                label: 'Өту деңгейі',
                                value: studentDocs.isNotEmpty
                                    ? '${((passCount / studentDocs.length) * 100).round()}%'
                                    : '0%',
                                icon: Icons
                                    .check_circle_outline_rounded,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 10),
                              _KpiCard(
                                label: 'Ең жоғары',
                                value: '$topScore',
                                icon: Icons.emoji_events_rounded,
                                color: AppColors.gold,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          const _SectionTitle('Пәндер бойынша орташа'),
                          const SizedBox(height: 12),
                          _SubjectStatsCard(stats: subjectAvg),

                          const SizedBox(height: 24),
                          _SectionTitle(
                              'Оқушылар (${filtered.length})'),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (v) =>
                                setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Оқушыны іздеу...',
                              prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: AppColors.navyBlue,
                                  size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                          Icons.clear_rounded),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(
                                            () => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 14),

                          if (filtered.isEmpty)
                            const _EmptyState(
                              icon: Icons.people_outline_rounded,
                              message: 'Оқушылар тіркелмеген',
                            )
                          else
                            ...filtered.map((data) {
                              final student = UserModel.fromMap(
                                  data, data['id'].toString());
                              final scoreModel =
                                  latestPerStudent[data['id']];
                              return _StudentTile(
                                curator: curator,
                                student: student,
                                latest: scoreModel,
                              );
                            }),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Пәндік орташаны есептеу ─────────────────────────────
  Map<String, _SubjectAvg> _calcSubjectAvg(List<ScoreModel> scores) {
    if (scores.isEmpty) return {};

    int kzSum = 0, readSum = 0, mathSum = 0, el1Sum = 0, el2Sum = 0;
    int kzMax = 0, readMax = 0, mathMax = 0, el1Max = 0, el2Max = 0;

    for (final s in scores) {
      kzSum += s.kazakhHistory;
      readSum += s.readingLiteracy;
      mathSum += s.mathLiteracy;
      el1Sum += s.elective1;
      el2Sum += s.elective2;
      if (s.kazakhHistory > kzMax) kzMax = s.kazakhHistory;
      if (s.readingLiteracy > readMax) readMax = s.readingLiteracy;
      if (s.mathLiteracy > mathMax) mathMax = s.mathLiteracy;
      if (s.elective1 > el1Max) el1Max = s.elective1;
      if (s.elective2 > el2Max) el2Max = s.elective2;
    }

    final n = scores.length;
    return {
      'kazakhHistory': _SubjectAvg(
          name: 'Қазақстан тарихы',
          avg: kzSum / n,
          max: kzMax,
          maxPossible: 20),
      'readingLiteracy': _SubjectAvg(
          name: 'Оқу сауаттылығы',
          avg: readSum / n,
          max: readMax,
          maxPossible: 10),
      'mathLiteracy': _SubjectAvg(
          name: 'Математикалық сауаттылық',
          avg: mathSum / n,
          max: mathMax,
          maxPossible: 10),
      'elective1': _SubjectAvg(
          name: '1-ші таңдау пәні',
          avg: el1Sum / n,
          max: el1Max,
          maxPossible: 50),
      'elective2': _SubjectAvg(
          name: '2-ші таңдау пәні',
          avg: el2Sum / n,
          max: el2Max,
          maxPossible: 50),
    };
  }
}

// ── Пәндік статистика моделі ──────────────────────────────
class _SubjectAvg {
  final String name;
  final double avg;
  final int max;
  final int maxPossible;
  const _SubjectAvg({
    required this.name,
    required this.avg,
    required this.max,
    required this.maxPossible,
  });
}

// ── HERO ──────────────────────────────────────────────────
class _CuratorHero extends StatelessWidget {
  final UserModel curator;
  final double classAvg;
  final int studentCount;

  const _CuratorHero({
    required this.curator,
    required this.classAvg,
    required this.studentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navyDark, AppColors.navyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 84, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                      child: Text(
                        curator.initials,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            curator.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.white),
                          ),
                          Text(
                            '${curator.className ?? "—"} сыныбы',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.gold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Stat(
                        label: 'Орташа балл',
                        value: classAvg.toStringAsFixed(1)),
                    const SizedBox(width: 28),
                    _Stat(
                        label: 'Оқушылар', value: '$studentCount'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.white.withValues(alpha: 0.6))),
        ],
      );
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

// ── ПӘНДІК СТАТИСТИКА КАРТОЧКАСЫ ──────────────────────────
class _SubjectStatsCard extends StatelessWidget {
  final Map<String, _SubjectAvg> stats;
  const _SubjectStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const _EmptyState(
        icon: Icons.bar_chart_rounded,
        message: 'Деректер жоқ',
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: stats.entries.map((e) {
          final stat = e.value;
          final fraction = stat.maxPossible > 0
              ? (stat.avg / stat.maxPossible).clamp(0.0, 1.0)
              : 0.0;
          final Color color;
          if (fraction >= 0.75) {
            color = AppColors.success;
          } else if (fraction >= 0.6)
            color = AppColors.gold;
          else
            color = AppColors.warning;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(stat.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              )),
                    ),
                    Text(
                      '${stat.avg.toStringAsFixed(1)} / ${stat.maxPossible}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ең үздік: ${stat.max} / ${stat.maxPossible}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── ОҚУШЫ ТАЙЛАСЫ ─────────────────────────────────────────
class _StudentTile extends StatelessWidget {
  final UserModel curator;
  final UserModel student;
  final ScoreModel? latest;

  const _StudentTile({
    required this.curator,
    required this.student,
    this.latest,
  });

  @override
  Widget build(BuildContext context) {
    final score = latest?.totalScore ?? -1;
    Color scoreColor;
    if (score < 0) {
      scoreColor = AppColors.textMuted;
    } else if (score >= 110)
      scoreColor = AppColors.success;
    else if (score >= 90)
      scoreColor = AppColors.gold;
    else if (score >= 70)
      scoreColor = AppColors.warning;
    else
      scoreColor = AppColors.error;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              StudentScoresScreen(curator: curator, student: student),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.navyBlue.withValues(alpha: 0.08),
              child: Text(
                student.initials,
                style: const TextStyle(
                  color: AppColors.navyBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      style: Theme.of(context).textTheme.titleSmall),
                  if (latest != null)
                    Text(
                      latest!.testName ?? 'Соңғы тест',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                score >= 0 ? '$score' : '—',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 44),
            const SizedBox(height: 12),
            Text(message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textMuted)),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.navyBlue,
              fontWeight: FontWeight.w700,
            ),
      );
}