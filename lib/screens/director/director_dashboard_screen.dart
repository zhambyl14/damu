// lib/screens/director/director_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../models/score_model.dart';
import '../../providers/auth_provider.dart';

class DirectorDashboardScreen extends StatelessWidget {
  const DirectorDashboardScreen({super.key});

  Future<void> _confirmSignOut(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Шығуды растау'),
        content: const Text('Сіз шынымен жүйеден шыққыңыз келе ме?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Болдырмау'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Шығу'),
          ),
        ],
      ),
    );
    if (confirmed == true && ctx.mounted) {
      await ctx.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final director = context.watch<AuthProvider>().userModel;
    if (director == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('users').stream(primaryKey: ['id']).eq('role', 'curator'),
      builder: (ctx, curatorSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client.from('users').stream(primaryKey: ['id']).eq('role', 'student'),
          builder: (ctx, studentSnap) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.from('scores').stream(primaryKey: ['id']),
              builder: (ctx, scoreSnap) {
                final curatorDocs = curatorSnap.data ?? [];
                final studentDocs = studentSnap.data ?? [];
                final scoreDocs = scoreSnap.data ?? [];

                final allScores = scoreDocs
                    .map((d) => ScoreModel.fromMap(d, d['id'].toString()))
                    .toList();

                // ── Әр куратор бойынша статистика ──
                final List<_CuratorStat> curatorStats =
                    curatorDocs.map((data) {
                  final curId = data['id'].toString();

                  final curScores = allScores
                      .where((s) => s.curatorId == curId)
                      .toList();

                  // Әр оқушының соңғы баллы
                  final Map<String, ScoreModel> latestPerStudent = {};
                  for (final s in curScores) {
                    final cur = latestPerStudent[s.studentId];
                    if (cur == null || s.date.isAfter(cur.date)) {
                      latestPerStudent[s.studentId] = s;
                    }
                  }

                  final latest = latestPerStudent.values.toList();
                  final avg = latest.isEmpty
                      ? 0.0
                      : latest.fold<int>(0, (s, m) => s + m.totalScore) /
                          latest.length;
                  final topScore = latest.isEmpty
                      ? 0
                      : latest
                          .map((m) => m.totalScore)
                          .reduce(math.max);

                  final studentCount = studentDocs.where((d) {
                    return d['curator_id'] == curId;
                  }).length;

                  return _CuratorStat(
                    id: curId,
                    name: data['name'] as String? ?? 'Куратор',
                    className: data['class_name'] as String? ?? '—',
                    avgScore: avg,
                    topScore: topScore,
                    studentCount: studentCount,
                  );
                }).toList()
                  ..sort(
                      (a, b) => b.avgScore.compareTo(a.avgScore));

                // Мектеп орташасы
                final schoolAvg = curatorStats.isNotEmpty
                    ? curatorStats.fold<double>(
                            0, (s, c) => s + c.avgScore) /
                        curatorStats.length
                    : 0.0;

                final totalStudents = studentDocs.length;
                final topClass = curatorStats.isNotEmpty
                    ? curatorStats.first.className
                    : '—';

                // ── Мектеп бойынша пәндік статистика ──
                final schoolSubjectStats = _calcSubjectAvg(allScores);

                // ── Үздік оқушы (мектеп бойынша ең жоғары балл) ──
                final Map<String, ScoreModel> bestPerStudent = {};
                for (final s in allScores) {
                  final cur = bestPerStudent[s.studentId];
                  if (cur == null || s.totalScore > cur.totalScore) {
                    bestPerStudent[s.studentId] = s;
                  }
                }
                ScoreModel? topStudent;
                for (final s in bestPerStudent.values) {
                  if (topStudent == null ||
                      s.totalScore > topStudent.totalScore) {
                    topStudent = s;
                  }
                }

                return Scaffold(
                  backgroundColor: AppColors.background,
                  body: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 220,
                        pinned: true,
                        backgroundColor: AppColors.navyBlue,
                        automaticallyImplyLeading: false,
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.logout_rounded,
                                color: AppColors.gold),
                            tooltip: 'Шығу',
                            onPressed: () =>
                                _confirmSignOut(context),
                          ),
                          const SizedBox(width: 4),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                          background: _DirectorHero(
                            director: director,
                            schoolAvg: schoolAvg,
                            totalStudents: totalStudents,
                            curatorCount: curatorStats.length,
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
                                errorBuilder: (_, __, ___) =>
                                    const Icon(
                                        Icons.school_rounded,
                                        color: AppColors.navyBlue,
                                        size: 24),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Директор панелі',
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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _KpiGrid(
                                schoolAvg: schoolAvg,
                                totalStudents: totalStudents,
                                curatorCount: curatorStats.length,
                                topClass: topClass,
                              ),

                              if (topStudent != null) ...[
                                const SizedBox(height: 26),
                                const _SectionTitle('Үздік оқушы'),
                                const SizedBox(height: 14),
                                _TopStudentCard(score: topStudent),
                              ],

                              const SizedBox(height: 26),
                              const _SectionTitle('Мектеп пәндері — орташа'),
                              const SizedBox(height: 14),
                              _SchoolSubjectStats(
                                  stats: schoolSubjectStats),

                              const SizedBox(height: 26),
                              const _SectionTitle('Сынып жетістіктері'),
                              const SizedBox(height: 14),
                              if (curatorStats.isEmpty)
                                const _EmptyState(
                                  icon: Icons.bar_chart_rounded,
                                  message: 'Деректер тіркелмеген',
                                )
                              else
                                _BarChart(curators: curatorStats),

                              const SizedBox(height: 26),
                              const _SectionTitle('Куратор рейтингі'),
                              const SizedBox(height: 14),
                              if (curatorStats.isEmpty)
                                const _EmptyState(
                                  icon: Icons.people_outline_rounded,
                                  message: 'Деректер тіркелмеген',
                                )
                              else
                                ...curatorStats
                                    .asMap()
                                    .entries
                                    .map((e) => _CuratorCard(
                                          stat: e.value,
                                          rank: e.key + 1,
                                          schoolAvg: schoolAvg,
                                          allScores: allScores,
                                        )),

                              const SizedBox(height: 26),
                              const _SectionTitle('Назар аудару'),
                              const SizedBox(height: 14),
                              _AlertsCard(curators: curatorStats),
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
      },
    );
  }

  Map<String, _SubjectAvg> _calcSubjectAvg(List<ScoreModel> scores) {
    if (scores.isEmpty) return {};

    int kzSum = 0, readSum = 0, mathSum = 0;
    int kzMax = 0, readMax = 0, mathMax = 0;

    for (final s in scores) {
      kzSum += s.kazakhHistory;
      readSum += s.readingLiteracy;
      mathSum += s.mathLiteracy;
      if (s.kazakhHistory > kzMax) kzMax = s.kazakhHistory;
      if (s.readingLiteracy > readMax) readMax = s.readingLiteracy;
      if (s.mathLiteracy > mathMax) mathMax = s.mathLiteracy;
    }

    final n = scores.length;
    final map = <String, _SubjectAvg>{
      'k': _SubjectAvg('Қазақстан тарихы', kzSum / n, kzMax,
          ScoreModel.maxKazakhHistory),
      'r': _SubjectAvg('Оқу сауаттылығы', readSum / n, readMax,
          ScoreModel.maxReadingLiteracy),
      'm': _SubjectAvg('Математикалық сауаттылық', mathSum / n, mathMax,
          ScoreModel.maxMathLiteracy),
    };
    // Бейіндік пәндер — НАҚТЫ аты бойынша (позициялық "Таңдау пәні 1/2" емес).
    final electives = _electiveAvgByName(scores);
    for (var i = 0; i < electives.length; i++) {
      map['e$i'] = electives[i];
    }
    return map;
  }
}

class _SubjectAvg {
  final String name;
  final double avg;
  final int max;
  final int maxPossible;
  const _SubjectAvg(this.name, this.avg, this.max, this.maxPossible);
}

/// Бейіндік пәндерді НАҚТЫ аты бойынша топтап орташасын есептейді.
/// Әр оқушының таңдауы әртүрлі болғандықтан, "Таңдау пәні 1/2" деген позициялық
/// атаудың орнына нақты пән атымен (мыс. "Физика", "Биология") көрсетеді.
List<_SubjectAvg> _electiveAvgByName(List<ScoreModel> scores) {
  final sums = <String, int>{};
  final counts = <String, int>{};
  final maxes = <String, int>{};

  void add(String? name, int val) {
    final key = (name == null || name.trim().isEmpty) ? null : name.trim();
    if (key == null) return; // аты белгісіз бейіндік — қоспаймыз
    sums[key] = (sums[key] ?? 0) + val;
    counts[key] = (counts[key] ?? 0) + 1;
    if (val > (maxes[key] ?? 0)) maxes[key] = val;
  }

  for (final s in scores) {
    add(s.elective1Name, s.elective1);
    add(s.elective2Name, s.elective2);
  }

  final out = <_SubjectAvg>[
    for (final key in sums.keys)
      _SubjectAvg(key, sums[key]! / counts[key]!, maxes[key] ?? 0,
          ScoreModel.maxElective),
  ];
  // Орташасы жоғарыдан төменге қарай — тізім тұрақты болуы үшін.
  out.sort((a, b) => b.avg.compareTo(a.avg));
  return out;
}

class _CuratorStat {
  final String id, name, className;
  final double avgScore;
  final int topScore, studentCount;

  const _CuratorStat({
    required this.id,
    required this.name,
    required this.className,
    required this.avgScore,
    required this.topScore,
    required this.studentCount,
  });
}

// ── HERO ──────────────────────────────────────────────────
class _DirectorHero extends StatelessWidget {
  final UserModel director;
  final double schoolAvg;
  final int totalStudents, curatorCount;

  const _DirectorHero({
    required this.director,
    required this.schoolAvg,
    required this.totalStudents,
    required this.curatorCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.navyDark,
            AppColors.navyBlue,
            Color(0xFF003D7A)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 230,
              height: 230,
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
                      backgroundColor:
                          AppColors.gold.withValues(alpha: 0.2),
                      child: Text(director.initials,
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(director.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: AppColors.white)),
                          Text(director.roleLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppColors.gold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _HStat(
                        label: 'Мектеп орташасы',
                        value: schoolAvg.toStringAsFixed(1),
                        isGold: true),
                    const SizedBox(width: 24),
                    _HStat(
                        label: 'Оқушылар',
                        value: '$totalStudents'),
                    const SizedBox(width: 24),
                    _HStat(
                        label: 'Сыныптар',
                        value: '$curatorCount'),
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

class _HStat extends StatelessWidget {
  final String label, value;
  final bool isGold;
  const _HStat({
    required this.label,
    required this.value,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    color: isGold ? AppColors.gold : AppColors.white,
                    fontWeight: FontWeight.w800,
                  )),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.white.withValues(alpha: 0.6))),
        ],
      );
}

class _KpiGrid extends StatelessWidget {
  final double schoolAvg;
  final int totalStudents, curatorCount;
  final String topClass;

  const _KpiGrid({
    required this.schoolAvg,
    required this.totalStudents,
    required this.curatorCount,
    required this.topClass,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'l': 'Мектеп орташасы',
        'v': schoolAvg.toStringAsFixed(1),
        'i': Icons.school_rounded,
        'c': AppColors.navyBlue
      },
      {
        'l': 'Барлық оқушылар',
        'v': '$totalStudents',
        'i': Icons.groups_rounded,
        'c': AppColors.info
      },
      {
        'l': 'Сыныптар',
        'v': '$curatorCount',
        'i': Icons.class_rounded,
        'c': AppColors.gold
      },
      {
        'l': 'Үздік сынып',
        'v': topClass,
        'i': Icons.emoji_events_rounded,
        'c': AppColors.success
      },
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: items.map((k) {
        final color = k['c'] as Color;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(k['i'] as IconData,
                    color: color, size: 17),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k['v'] as String,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                              fontWeight: FontWeight.w800)),
                  Text(k['l'] as String,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── ҮЗДІК ОҚУШЫ ───────────────────────────────────────────
class _TopStudentCard extends StatelessWidget {
  final ScoreModel score;
  const _TopStudentCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.goldDark, AppColors.gold, AppColors.goldLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('🥇', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(score.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.navyDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    score.className != null && score.className!.isNotEmpty
                        ? '${score.className} сыныбы · мектеп көшбасшысы'
                        : 'Мектеп көшбасшысы',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.navyDark.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${score.totalScore}',
                  style: const TextStyle(
                      color: AppColors.navyDark,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1)),
              Text('/ ${ScoreModel.maxTotal} балл',
                  style: TextStyle(
                      color: AppColors.navyDark.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── МЕКТЕП ПӘНДІК СТАТИСТИКАСЫ ────────────────────────────
class _SchoolSubjectStats extends StatelessWidget {
  final Map<String, _SubjectAvg> stats;
  const _SchoolSubjectStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const _EmptyState(
        icon: Icons.bar_chart_rounded,
        message: 'Деректер жоқ',
      );
    }

    // Үздік және төмен пәнді анықтау (фракция бойынша)
    final entries = stats.values.toList();
    entries.sort((a, b) =>
        (b.avg / b.maxPossible).compareTo(a.avg / a.maxPossible));
    final bestSubject = entries.first;
    final worstSubject = entries.last;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.trending_up_rounded,
                            color: AppColors.success, size: 16),
                        const SizedBox(width: 6),
                        Text('Үздік пән',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(bestSubject.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        '${bestSubject.avg.toStringAsFixed(1)} / ${bestSubject.maxPossible}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.trending_down_rounded,
                            color: AppColors.warning, size: 16),
                        const SizedBox(width: 6),
                        Text('Әлсіз пән',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(worstSubject.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        '${worstSubject.avg.toStringAsFixed(1)} / ${worstSubject.maxPossible}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
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
                padding: const EdgeInsets.only(bottom: 12),
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
                      'Ең үздік нәтиже: ${stat.max} / ${stat.maxPossible}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── BAR CHART (Сыныптар салыстыруы) ───────────────────────
class _BarChart extends StatelessWidget {
  final List<_CuratorStat> curators;
  const _BarChart({required this.curators});

  @override
  Widget build(BuildContext context) {
    final maxAvg = curators
        .map((c) => c.avgScore)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сынып орташаларын салыстыру',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 18),
          ...curators.map((c) {
            final fraction = (c.avgScore / 140).clamp(0.0, 1.0);
            final isTop = c.avgScore == maxAvg;
            final Color color;
            if (c.avgScore >= 100) {
              color = AppColors.success;
            } else if (c.avgScore >= 85)
              color = AppColors.gold;
            else
              color = AppColors.warning;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(c.className,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius:
                                BorderRadius.circular(5),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(
                            height: 26,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius:
                                  BorderRadius.circular(5),
                            ),
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.only(right: 7),
                            child: Text(
                              c.avgScore.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isTop) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star_rounded,
                        color: AppColors.gold, size: 16),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── КУРАТОР КАРТОЧКА ──────────────────────────────────────
class _CuratorCard extends StatelessWidget {
  final _CuratorStat stat;
  final int rank;
  final double schoolAvg;
  final List<ScoreModel> allScores;

  const _CuratorCard({
    required this.stat,
    required this.rank,
    required this.schoolAvg,
    required this.allScores,
  });

  @override
  Widget build(BuildContext context) {
    final isAbove = stat.avgScore >= schoolAvg;
    final diff = stat.avgScore - schoolAvg;
    final Color avgColor;
    if (stat.avgScore >= 100) {
      avgColor = AppColors.success;
    } else if (stat.avgScore >= 85)
      avgColor = AppColors.gold;
    else
      avgColor = AppColors.warning;

    return InkWell(
      onTap: () => _showSubjectBreakdown(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: rank == 1
                ? AppColors.gold.withValues(alpha: 0.5)
                : AppColors.divider,
            width: rank == 1 ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? AppColors.gold
                        : rank == 2
                            ? const Color(0xFFB0B0B0)
                            : rank == 3
                                ? const Color(0xFFCD7F32)
                                : AppColors.navyBlue
                                    .withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('#$rank',
                        style: TextStyle(
                          color: rank <= 3
                              ? AppColors.white
                              : AppColors.navyBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stat.name,
                          style:
                              Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.navyBlue
                                  .withValues(alpha: 0.07),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Text(
                                'Сынып ${stat.className}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: AppColors.navyBlue)),
                          ),
                          const SizedBox(width: 6),
                          Text('${stat.studentCount} оқушы',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(stat.avgScore.toStringAsFixed(1),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                color: avgColor,
                                fontWeight: FontWeight.w800)),
                    Text('орт. балл',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            Row(
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        color: AppColors.gold, size: 14),
                    const SizedBox(width: 4),
                    Text('${stat.topScore} ең жоғары',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAbove
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAbove
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: isAbove
                            ? AppColors.success
                            : AppColors.error,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${diff.abs().toStringAsFixed(1)} орт.',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: isAbove
                                  ? AppColors.success
                                  : AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSubjectBreakdown(BuildContext context) {
    // Осы кураторға тиесілі баллдар
    final curScores =
        allScores.where((s) => s.curatorId == stat.id).toList();
    if (curScores.isEmpty) return;

    int kzSum = 0, readSum = 0, mathSum = 0;
    for (final s in curScores) {
      kzSum += s.kazakhHistory;
      readSum += s.readingLiteracy;
      mathSum += s.mathLiteracy;
    }
    final n = curScores.length;
    final electives = _electiveAvgByName(curScores);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(stat.name, style: Theme.of(context).textTheme.titleMedium),
            Text('Сынып ${stat.className} — пәндік талдау',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            _row(context, 'Қазақстан тарихы', kzSum / n,
                ScoreModel.maxKazakhHistory),
            _row(context, 'Оқу сауаттылығы', readSum / n,
                ScoreModel.maxReadingLiteracy),
            _row(context, 'Математикалық сауаттылық', mathSum / n,
                ScoreModel.maxMathLiteracy),
            for (final e in electives)
              _row(context, e.name, e.avg, e.maxPossible),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext c, String t, double avg, int max) {
    final fraction = (avg / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${avg.toStringAsFixed(1)} / $max',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation(AppColors.navyBlue),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ЕСКЕРТУ КАРТОЧКАСЫ ────────────────────────────────────
class _AlertsCard extends StatelessWidget {
  final List<_CuratorStat> curators;
  const _AlertsCard({required this.curators});

  @override
  Widget build(BuildContext context) {
    final low = curators
        .where((c) => c.avgScore < 85 && c.avgScore > 0)
        .toList();

    if (low.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Барлық сыныптар жоғары көрсеткіште. Тамаша!',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Text('${low.length} сынып 85-тен төмен орташамен',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: 10),
          ...low.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_right_rounded,
                        color: AppColors.warning, size: 16),
                    Text(
                      'Сынып ${c.className} — ${c.avgScore.toStringAsFixed(1)} орт.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )),
        ],
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
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 40),
            const SizedBox(height: 10),
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