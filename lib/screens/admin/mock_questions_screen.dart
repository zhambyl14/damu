// lib/screens/admin/mock_questions_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../data/subjects_catalog.dart';
import '../../models/mock_test_model.dart';
import '../../services/mock_test_service.dart';
import 'add_edit_mock_question_screen.dart';
import 'bulk_import_screen.dart';

/// Әкімші бір мок тесттің сұрақтарын басқарады (бөлімдерге топтап).
class MockQuestionsScreen extends StatelessWidget {
  final MockTest mock;
  const MockQuestionsScreen({super.key, required this.mock});

  MockTestService get _service => MockTestService();

  String _sectionTitle(MockQuestion q) {
    if (q.section == MockSection.elective) {
      return SubjectCatalog.titleOf(q.subjectId ?? '');
    }
    return MockSection.label(q.section);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(mock.title),
        backgroundColor: AppColors.navyBlue,
        actions: [
          IconButton(
            tooltip: 'Жаппай импорт (PDF/мәтін)',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BulkImportScreen.mock(mockId: mock.id),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDark,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Сұрақ қосу'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditMockQuestionScreen(mockId: mock.id),
          ),
        ),
      ),
      body: StreamBuilder<List<MockQuestion>>(
        stream: _service.watchQuestions(mock.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.quiz_outlined,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('Сұрақтар әлі жоқ',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Text('Әр бөлімге сұрақтар қосыңыз',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }

          // Бөлім бойынша сан
          final counts = <String, int>{};
          for (final q in items) {
            final key = _sectionTitle(q);
            counts[key] = (counts[key] ?? 0) + 1;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Барлығы ${items.length} сұрақ',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppColors.navyBlue)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: counts.entries
                          .map((e) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: AppColors.divider),
                                ),
                                child: Text('${e.key}: ${e.value}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...items.map((q) => _card(context, q)),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, MockQuestion q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.navyBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_sectionTitle(q),
                    style: const TextStyle(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 10)),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted),
                onSelected: (v) {
                  if (v == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditMockQuestionScreen(
                            mockId: mock.id, existing: q),
                      ),
                    );
                  } else {
                    _confirmDelete(context, q);
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
            ],
          ),
          Text(q.question, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...List.generate(q.options.length, (i) {
            final correct = i == q.correctIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Icon(
                      correct
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 15,
                      color:
                          correct ? AppColors.success : AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(q.options[i],
                        style: TextStyle(
                            fontSize: 13,
                            color: correct
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontWeight:
                                correct ? FontWeight.w700 : FontWeight.w400)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, MockQuestion q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Сұрақты өшіру'),
        content: Text('"${q.question}" — өшіргіңіз келе ме?',
            maxLines: 3, overflow: TextOverflow.ellipsis),
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
    if (ok == true) await _service.deleteQuestion(q);
  }
}
