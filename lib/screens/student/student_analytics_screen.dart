// lib/screens/student/student_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../models/score_model.dart';

enum AnalyticsScope { school, classRank, byTest, bySubject }

class StudentAnalyticsScreen extends StatefulWidget {
  /// Қазіргі оқушының UID-і
  final String studentId;
  const StudentAnalyticsScreen({super.key, required this.studentId});

  @override
  State<StudentAnalyticsScreen> createState() => _StudentAnalyticsScreenState();
}

class _StudentAnalyticsScreenState extends State<StudentAnalyticsScreen> {
  AnalyticsScope _scope = AnalyticsScope.school;
  String? _selectedTestName;
  String _selectedSubject = 'kazakhHistory';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Менің рейтингім'),
        backgroundColor: AppColors.navyBlue,
        elevation: 0,
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: Supabase.instance.client.from('scores').stream(primaryKey: ['id']),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.navyBlue),
            );
          }

          final allScores = (snap.data ?? [])
              .map((d) => ScoreModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
              .toList();

          // Қазіргі оқушының сыныбын анықтау
          String? myClass;
          String? myCuratorId;
          for (final s in allScores) {
            if (s.studentId == widget.studentId) {
              myClass = s.className;
              myCuratorId = s.curatorId;
              break;
            }
          }

          // Барлық тест атаулары
          final testNames = allScores
              .where((s) => s.testName != null && s.testName!.isNotEmpty)
              .map((s) => s.testName!)
              .toSet()
              .toList()
            ..sort();

          if (_selectedTestName == null && testNames.isNotEmpty) {
            _selectedTestName = testNames.first;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(
                  studentId: widget.studentId,
                  allScores: allScores,
                ),
                const SizedBox(height: 24),

                const _SectionTitle('Сүзу'),
                const SizedBox(height: 12),
                _ScopeSelector(
                  scope: _scope,
                  onChanged: (s) => setState(() => _scope = s),
                ),
                const SizedBox(height: 18),

                // Қосымша сүзгілер
                if (_scope == AnalyticsScope.byTest) ...[
                  if (testNames.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text('Тесттер табылмады',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textMuted)),
                    )
                  else
                    _TestPicker(
                      tests: testNames,
                      selected: _selectedTestName,
                      onChanged: (v) => setState(() => _selectedTestName = v),
                    ),
                  const SizedBox(height: 18),
                ],
                if (_scope == AnalyticsScope.bySubject) ...[
                  _SubjectPicker(
                    selected: _selectedSubject,
                    onChanged: (v) => setState(() => _selectedSubject = v),
                  ),
                  const SizedBox(height: 18),
                ],

                const _SectionTitle('Нәтиже'),
                const SizedBox(height: 12),
                _RankingBuilder(
                  scope: _scope,
                  studentId: widget.studentId,
                  myCuratorId: myCuratorId,
                  myClass: myClass,
                  allScores: allScores,
                  selectedTestName: _selectedTestName,
                  selectedSubject: _selectedSubject,
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Жоғарғы хедер ─────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  final String studentId;
  final List<ScoreModel> allScores;
  const _HeaderCard({required this.studentId, required this.allScores});

  @override
  Widget build(BuildContext context) {
    // Әр оқушының ең жоғары балы
    final Map<String, int> bestPerStudent = {};
    for (final s in allScores) {
      final cur = bestPerStudent[s.studentId] ?? 0;
      if (s.totalScore > cur) bestPerStudent[s.studentId] = s.totalScore;
    }

    final ranked = bestPerStudent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final myRank = ranked.indexWhere((e) => e.key == studentId) + 1;
    final myScore = bestPerStudent[studentId] ?? 0;
    final total = ranked.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDark, AppColors.navyBlue, Color(0xFF003D7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyBlue.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text('Жалпы мектеп бойынша',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Сіздің орныңыз',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        myRank > 0 ? '#$myRank' : '—',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      if (myRank > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, left: 4),
                          child: Text('/ $total',
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.6),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Ең үздік балл',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 4),
                  Text(
                    '$myScore',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (myRank > 0 && myRank <= 3) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    myRank == 1 ? '🥇' : myRank == 2 ? '🥈' : '🥉',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    myRank == 1
                        ? 'Сіз — мектеп көшбасшысысыз!'
                        : 'ТОП-3 ішіндесіз!',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Фильтр чиптері ────────────────────────────────────────
class _ScopeSelector extends StatelessWidget {
  final AnalyticsScope scope;
  final ValueChanged<AnalyticsScope> onChanged;
  const _ScopeSelector({required this.scope, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      (AnalyticsScope.school, 'Мектеп', Icons.school_rounded),
      (AnalyticsScope.classRank, 'Сынып', Icons.class_rounded),
      (AnalyticsScope.byTest, 'Тест', Icons.assignment_rounded),
      (AnalyticsScope.bySubject, 'Пән', Icons.book_rounded),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final selected = scope == item.$1;
        return GestureDetector(
          onTap: () => onChanged(item.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.navyBlue : AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.navyBlue : AppColors.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.$3,
                  size: 16,
                  color: selected ? AppColors.gold : AppColors.navyBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  item.$2,
                  style: TextStyle(
                    color: selected ? AppColors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Тест таңдау ───────────────────────────────────────────
class _TestPicker extends StatelessWidget {
  final List<String> tests;
  final String? selected;
  final ValueChanged<String> onChanged;
  const _TestPicker({
    required this.tests,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tests.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isSel = tests[i] == selected;
          return GestureDetector(
            onTap: () => onChanged(tests[i]),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isSel
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSel ? AppColors.gold : AppColors.divider,
                ),
              ),
              child: Text(
                tests[i],
                style: TextStyle(
                  color: isSel ? AppColors.goldDark : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Пән таңдау ────────────────────────────────────────────
class _SubjectPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _SubjectPicker({required this.selected, required this.onChanged});

  static const _items = {
    'kazakhHistory': 'Қазақстан тарихы',
    'readingLiteracy': 'Оқу сауаттылығы',
    'mathLiteracy': 'Матем. сауаттылық',
    'elective1': '1-ші таңдау',
    'elective2': '2-ші таңдау',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final key = _items.keys.elementAt(i);
          final label = _items[key]!;
          final isSel = key == selected;
          return GestureDetector(
            onTap: () => onChanged(key),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isSel
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSel ? AppColors.gold : AppColors.divider,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSel ? AppColors.goldDark : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Рейтинг тізімі ────────────────────────────────────────
class _RankingBuilder extends StatelessWidget {
  final AnalyticsScope scope;
  final String studentId;
  final String? myCuratorId;
  final String? myClass;
  final List<ScoreModel> allScores;
  final String? selectedTestName;
  final String selectedSubject;

  const _RankingBuilder({
    required this.scope,
    required this.studentId,
    required this.myCuratorId,
    required this.myClass,
    required this.allScores,
    required this.selectedTestName,
    required this.selectedSubject,
  });

  @override
  Widget build(BuildContext context) {
    final List<_Entry> entries;

    switch (scope) {
      case AnalyticsScope.school:
        entries = _buildBestPerStudent(allScores);
        break;
      case AnalyticsScope.classRank:
        if (myCuratorId == null) {
          return _empty(context, 'Сынып тіркелмеген');
        }
        final classScores =
            allScores.where((s) => s.curatorId == myCuratorId).toList();
        entries = _buildBestPerStudent(classScores);
        break;
      case AnalyticsScope.byTest:
        if (selectedTestName == null) {
          return _empty(context, 'Тест таңдаңыз');
        }
        final testScores =
            allScores.where((s) => s.testName == selectedTestName).toList();
        entries = _buildPerTest(testScores);
        break;
      case AnalyticsScope.bySubject:
        entries = _buildBySubject(allScores, selectedSubject);
        break;
    }

    if (entries.isEmpty) return _empty(context, 'Деректер табылмады');

    entries.sort((a, b) => b.value.compareTo(a.value));
    final myIdx = entries.indexWhere((e) => e.studentId == studentId);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          if (myIdx >= 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18)),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_rounded,
                      color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Сіздің орныңыз: #${myIdx + 1} / ${entries.length}',
                    style: const TextStyle(
                      color: AppColors.goldDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${entries[myIdx].value} балл',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ...entries.take(20).toList().asMap().entries.map((e) {
            final rank = e.key + 1;
            final entry = e.value;
            final isMe = entry.studentId == studentId;
            final visible = entries.take(20).length;
            final isLast = rank == visible;

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.navyBlue.withValues(alpha: 0.05)
                    : Colors.transparent,
                border: !isLast
                    ? const Border(
                        bottom: BorderSide(
                            color: AppColors.divider, width: 1))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: rank <= 3
                        ? Text(
                            rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                            style: const TextStyle(fontSize: 20),
                          )
                        : Text(
                            '#$rank',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? '${entry.name} (Сіз)' : entry.name,
                          style: TextStyle(
                            fontWeight:
                                isMe ? FontWeight.w700 : FontWeight.w500,
                            color: isMe
                                ? AppColors.navyBlue
                                : AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        if (entry.className != null)
                          Text(
                            entry.className!,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      color: rank == 1
                          ? AppColors.gold
                          : AppColors.navyBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (entries.length > 20)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Барлығы ${entries.length} оқушы. Алғашқы 20-сы көрсетілді.',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Әр оқушының ең үздік балы
  List<_Entry> _buildBestPerStudent(List<ScoreModel> scores) {
    final Map<String, _Entry> best = {};
    for (final s in scores) {
      final cur = best[s.studentId];
      if (cur == null || s.totalScore > cur.value) {
        best[s.studentId] = _Entry(
          studentId: s.studentId,
          name: s.studentName,
          className: s.className,
          value: s.totalScore,
        );
      }
    }
    return best.values.toList();
  }

  // Берілген тест бойынша (бір оқушыға бір ғана нәтиже болуы тиіс — бірақ қауіпсіздік үшін best аламыз)
  List<_Entry> _buildPerTest(List<ScoreModel> scores) {
    final Map<String, _Entry> best = {};
    for (final s in scores) {
      final cur = best[s.studentId];
      if (cur == null || s.totalScore > cur.value) {
        best[s.studentId] = _Entry(
          studentId: s.studentId,
          name: s.studentName,
          className: s.className,
          value: s.totalScore,
        );
      }
    }
    return best.values.toList();
  }

  // Бір пән бойынша ең үздік
  List<_Entry> _buildBySubject(List<ScoreModel> scores, String subject) {
    int getValue(ScoreModel s) {
      switch (subject) {
        case 'kazakhHistory':   return s.kazakhHistory;
        case 'readingLiteracy': return s.readingLiteracy;
        case 'mathLiteracy':    return s.mathLiteracy;
        case 'elective1':       return s.elective1;
        case 'elective2':       return s.elective2;
        default:                return s.totalScore;
      }
    }

    final Map<String, _Entry> best = {};
    for (final s in scores) {
      final v = getValue(s);
      final cur = best[s.studentId];
      if (cur == null || v > cur.value) {
        best[s.studentId] = _Entry(
          studentId: s.studentId,
          name: s.studentName,
          className: s.className,
          value: v,
        );
      }
    }
    return best.values.toList();
  }

  Widget _empty(BuildContext c, String text) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.inbox_outlined,
                  color: AppColors.textMuted, size: 40),
              const SizedBox(height: 8),
              Text(text,
                  style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
      );
}

class _Entry {
  final String studentId;
  final String name;
  final String? className;
  final int value;
  const _Entry({
    required this.studentId,
    required this.name,
    this.className,
    required this.value,
  });
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