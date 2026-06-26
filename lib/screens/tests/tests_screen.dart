// lib/screens/tests/tests_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../models/score_model.dart';
import '../../models/user_model.dart';
import '../../models/mock_test_model.dart';
import '../../services/mock_test_service.dart';
import '../../providers/auth_provider.dart';
import 'mock_test_screen.dart';

class TestsScreen extends StatelessWidget {
  const TestsScreen({super.key});

  static const _months = [
    'Қаңтар', 'Ақпан', 'Наурыз', 'Сәуір',
    'Мамыр', 'Маусым', 'Шілде', 'Тамыз',
    'Қыркүйек', 'Қазан', 'Қараша', 'Желтоқсан'
  ];

  String _formatDate(DateTime d) {
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Менің тесттерім'),
        backgroundColor: AppColors.navyBlue,
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: Supabase.instance.client
            .from('scores')
            .stream(primaryKey: ['id'])
            .eq('student_id', user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.navyBlue),
            );
          }

          final docs = snap.data ?? [];
          final scores = docs
              .map((d) => ScoreModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          // Бұрын тапсырылған айлық моктардың id-лері — қайта тапсыруға болмайды.
          final takenMockIds =
              scores.map((s) => s.mockId).whereType<String>().toSet();

          // Бүкіл бет бір ListView ішінде — жоғарғы карталар да, нәтижелер де
          // бірге скролл болады (бұрын тек нәтижелер тізімі ғана скролл болатын).
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
                // Хедер
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF002147), Color(0xFF003167)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.assignment_rounded,
                            color: AppColors.gold, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ҰБТ Сынақтамалар',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: AppColors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Барлығы ${scores.length} тест тапсырылған',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        AppColors.white.withValues(alpha: 0.65),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                _PracticeCard(user: user),
                const SizedBox(height: 24),
                _AvailableMockTests(user: user, takenMockIds: takenMockIds),
                const SizedBox(height: 24),
                Text('Менің нәтижелерім',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.navyBlue,
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 12),

                if (scores.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_outlined,
                              color: AppColors.textMuted, size: 56),
                          const SizedBox(height: 12),
                          Text('Тесттер тапсырылмаған',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(scores.length, (i) {
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: i == scores.length - 1 ? 0 : 12),
                      child: _TestCard(
                        score: scores[i],
                        dateStr: _formatDate(scores[i].date),
                      ),
                    );
                  }),
              ],
            );
        },
      ),
    );
  }
}

// ── ҚОЛЖЕТІМДІ МОК ТЕСТТЕР ────────────────────────────────
/// Дайындық тесті — оқушы кез келген уақытта тапсыра алады, рейтингке әсерсіз.
class _PracticeCard extends StatelessWidget {
  final UserModel user;
  const _PracticeCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MockTestScreen.practice(student: user),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: AppColors.gold, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Дайындық тесті',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.navyBlue,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Кез келген уақытта жаттық — рейтингке әсер етпейді',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableMockTests extends StatelessWidget {
  final UserModel user;
  final Set<String> takenMockIds;
  const _AvailableMockTests({required this.user, required this.takenMockIds});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MockTest>>(
      stream: MockTestService().watchActive(),
      builder: (context, snap) {
        // Тек қолжетімді (available_from өткен) мок тесттер. Сынып жолы бос НЕМЕСЕ
        // сәйкес (trim+lowerCase) НЕМЕСЕ моктың авторы — оқушының өз кураторы болса
        // көрінеді (сынып жазуы сәл өзгеше болса да жоғалмауы үшін).
        final myClass = (user.className ?? '').trim().toLowerCase();
        final mocks = (snap.data ?? []).where((m) {
          if (!m.isAvailableNow) return false;
          if (takenMockIds.contains(m.id)) return false; // бір рет қана тапсыру
          final cls = m.className?.trim() ?? '';
          final byClass = cls.isEmpty || cls.toLowerCase() == myClass;
          final byCurator = m.createdBy != null && m.createdBy == user.curatorId;
          return byClass || byCurator;
        }).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_rounded,
                    color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Text('Қолжетімді мок тесттер',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            if (mocks.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text('Қазір қолжетімді мок тест жоқ',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMuted)),
              )
            else
              ...mocks.map((m) => _mockCard(context, m)),
          ],
        );
      },
    );
  }

  Widget _mockCard(BuildContext context, MockTest m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDark, AppColors.navyBlue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fact_check_rounded,
                color: AppColors.gold, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (m.description != null && m.description!.isNotEmpty)
                  Text(m.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.65)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MockTestScreen(mock: m, student: user),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navyDark,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Тапсыру'),
          ),
        ],
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final ScoreModel score;
  final String dateStr;

  const _TestCard({required this.score, required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final isStateExam = score.testType == 'state_exam';

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isStateExam
                  ? AppColors.gold.withValues(alpha: 0.4)
                  : AppColors.divider,
              width: isStateExam ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isStateExam
                      ? AppColors.gold.withValues(alpha: 0.12)
                      : AppColors.navyBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isStateExam
                      ? Icons.gavel_rounded
                      : Icons.assignment_turned_in_rounded,
                  color: isStateExam ? AppColors.gold : AppColors.navyBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            score.testName ?? 'ҰБТ Сынақтамасы',
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isStateExam)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'РЕСМИ',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${score.totalScore}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          color: score.scoreColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    '/ 140',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
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
            Text(
              score.testName ?? 'ҰБТ Сынақтамасы',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(dateStr,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),

            _scoreRow(context, 'Қазақстан тарихы', score.kazakhHistory,
                ScoreModel.maxKazakhHistory),
            const Divider(height: 16),
            _scoreRow(context, 'Оқу сауаттылығы', score.readingLiteracy,
                ScoreModel.maxReadingLiteracy),
            const Divider(height: 16),
            _scoreRow(context, 'Математикалық сауаттылық', score.mathLiteracy,
                ScoreModel.maxMathLiteracy),
            const Divider(height: 16),
            _scoreRow(
                context,
                score.elective1Name ?? 'Таңдау пәні 1',
                score.elective1,
                ScoreModel.maxElective),
            const Divider(height: 16),
            _scoreRow(
                context,
                score.elective2Name ?? 'Таңдау пәні 2',
                score.elective2,
                ScoreModel.maxElective),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.navyBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ЖАЛПЫ:',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.navyBlue)),
                  Text(
                    '${score.totalScore} / 140',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreRow(BuildContext c, String title, int s, int max) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            child: Text(title,
                style: Theme.of(c).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500))),
        Text(
          '$s / $max',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
      ],
    );
  }
}