// lib/screens/curator/topic_content_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/question_model.dart';
import '../../models/flashcard_model.dart';
import '../../services/content_service.dart';
import '../admin/bulk_import_screen.dart';
import 'add_edit_question_screen.dart';
import 'add_edit_flashcard_screen.dart';

/// Бір тақырыптың сұрақтары мен флешкарталарын басқару.
class TopicContentScreen extends StatefulWidget {
  final String subjectId;
  final String topicId;
  final String topicTitle;
  final String curatorUid;

  const TopicContentScreen({
    super.key,
    required this.subjectId,
    required this.topicId,
    required this.topicTitle,
    required this.curatorUid,
  });

  @override
  State<TopicContentScreen> createState() => _TopicContentScreenState();
}

class _TopicContentScreenState extends State<TopicContentScreen>
    with SingleTickerProviderStateMixin {
  final _content = ContentService();
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.topicTitle),
        backgroundColor: AppColors.navyBlue,
        actions: [
          IconButton(
            tooltip: 'Жаппай импорт (PDF/мәтін)',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () {
              final isCards = _tab.index == 1;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => isCards
                      ? BulkImportScreen.topicFlashcards(
                          subjectId: widget.subjectId,
                          topicId: widget.topicId,
                          topicTitle: widget.topicTitle,
                        )
                      : BulkImportScreen.topicQuestions(
                          subjectId: widget.subjectId,
                          topicId: widget.topicId,
                          topicTitle: widget.topicTitle,
                        ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Сұрақтар', icon: Icon(Icons.quiz_rounded)),
            Tab(text: 'Флешкарталар', icon: Icon(Icons.style_rounded)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDark,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tab.index == 0 ? 'Сұрақ қосу' : 'Флешкарта қосу'),
        onPressed: () {
          if (_tab.index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditQuestionScreen(
                  subjectId: widget.subjectId,
                  topicId: widget.topicId,
                  curatorUid: widget.curatorUid,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditFlashcardScreen(
                  subjectId: widget.subjectId,
                  topicId: widget.topicId,
                  curatorUid: widget.curatorUid,
                ),
              ),
            );
          }
        },
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _questionsTab(),
          _flashcardsTab(),
        ],
      ),
    );
  }

  // ── СҰРАҚТАР ─────────────────────────────────────────────
  Widget _questionsTab() {
    return StreamBuilder<List<QuestionModel>>(
      stream: _content.watchQuestions(widget.subjectId, widget.topicId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.navyBlue));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return _empty('Сұрақтар әлі жоқ', 'Төмендегі батырмамен қосыңыз',
              Icons.quiz_outlined);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _questionCard(items[i], i + 1),
        );
      },
    );
  }

  Widget _questionCard(QuestionModel q, int number) {
    return Container(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.navyBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('№$number',
                    style: const TextStyle(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(q.question,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              _menu(
                onEdit: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditQuestionScreen(
                      subjectId: widget.subjectId,
                      topicId: widget.topicId,
                      curatorUid: widget.curatorUid,
                      existing: q,
                    ),
                  ),
                ),
                onDelete: () => _confirmDelete(
                  'Сұрақты өшіру',
                  q.question,
                  () => _content.deleteQuestion(q),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(q.options.length, (i) {
            final correct = i == q.correctIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    correct
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 16,
                    color: correct ? AppColors.success : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${String.fromCharCode(65 + i)}. ${q.options[i]}',
                      style: TextStyle(
                        color: correct
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight:
                            correct ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── ФЛЕШКАРТАЛАР ─────────────────────────────────────────
  Widget _flashcardsTab() {
    return StreamBuilder<List<FlashcardModel>>(
      stream: _content.watchFlashcards(widget.subjectId, widget.topicId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.navyBlue));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return _empty('Флешкарталар әлі жоқ',
              'Төмендегі батырмамен қосыңыз', Icons.style_outlined);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _flashcardCard(items[i]),
        );
      },
    );
  }

  Widget _flashcardCard(FlashcardModel f) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.front,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(f.back,
                    style: Theme.of(context).textTheme.bodySmall),
                if (f.hint != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                          size: 14, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(f.hint!,
                            style: const TextStyle(
                                color: AppColors.goldDark,
                                fontSize: 12,
                                fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _menu(
            onEdit: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditFlashcardScreen(
                  subjectId: widget.subjectId,
                  topicId: widget.topicId,
                  curatorUid: widget.curatorUid,
                  existing: f,
                ),
              ),
            ),
            onDelete: () => _confirmDelete(
              'Флешкартаны өшіру',
              f.front,
              () => _content.deleteFlashcard(f),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu({required VoidCallback onEdit, required VoidCallback onDelete}) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_rounded, size: 18, color: AppColors.navyBlue),
            SizedBox(width: 10),
            Text('Түзету'),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
            SizedBox(width: 10),
            Text('Өшіру'),
          ]),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      String title, String body, Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text('"$body" — өшіргіңіз келе ме?',
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
    if (ok == true) await action();
  }

  Widget _empty(String title, String subtitle, IconData icon) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}
