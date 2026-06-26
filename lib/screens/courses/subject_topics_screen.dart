// lib/screens/courses/subject_topics_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../models/topic_model.dart';
import '../../models/flashcard_model.dart';
import '../../services/content_service.dart';
import '../../services/video_progress_service.dart';
import '../flashcards/flashcards_screen.dart';
import '../flashcards/flashcard_study_screen.dart';
import 'video_lesson_screen.dart';

/// Оқушы пәнді ашқанда — тақырыптар тізімі. Әр тақырыптан:
///  • видеосабақ (тек online),
///  • тақырыптық тест (тек online),
///  • флешкарта (барлығы).
class SubjectTopicsScreen extends StatelessWidget {
  final String subjectId;
  final String subjectTitle;
  final IconData icon;
  final Color color;
  final UserModel student;

  const SubjectTopicsScreen({
    super.key,
    required this.subjectId,
    required this.subjectTitle,
    required this.icon,
    required this.color,
    required this.student,
  });

  ContentService get _content => ContentService();

  /// Контенті бар тақырып ӘРҚАШАН көрінеді. Оффлайн оқушыға видео/тест чиптері
  /// құлыпталған күйде көрсетіледі (бұрын мұндай тақырып мүлдем жасырылатын).
  bool _visible(TopicModel t) {
    return t.hasVideo || t.questionCount > 0 || t.flashcardCount > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(subjectTitle),
        backgroundColor: AppColors.navyBlue,
      ),
      body: StreamBuilder<Set<String>>(
        stream: student.isStudent
            ? VideoProgressService().watchProgress(student.uid)
            : const Stream.empty(),
        initialData: const <String>{},
        builder: (context, progressSnap) {
          final watched = progressSnap.data ?? {};
          return StreamBuilder<List<TopicModel>>(
            stream: _content.watchTopics(subjectId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.navyBlue));
              }
              final topics = (snap.data ?? []).where(_visible).toList();

              if (topics.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 56, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text('Бұл пәнде әзірге материал жоқ',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        Text(
                          student.isOfflineStudent
                              ? 'Оффлайн оқушыларға флешкарталар қолжетімді болады.'
                              : 'Материалдар қосылған соң осында пайда болады.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Видео бар тақырыптар санын есептеу (видеосабақ прогресі үшін)
              final videoTopics = topics
                  .where((t) => t.hasVideo && student.canAccessVideoLessons)
                  .toList();
              final watchedCount = videoTopics
                  .where((t) => watched.contains('${subjectId}_${t.id}'))
                  .length;

              return Column(
                children: [
                  if (videoTopics.isNotEmpty)
                    _progressBar(context, watchedCount, videoTopics.length),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      itemCount: topics.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _topicCard(context, topics[i], i + 1, watched),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _progressBar(BuildContext context, int done, int total) {
    final pct = total == 0 ? 0.0 : done / total;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Видеосабақ прогресі',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              Text('$done / $total',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.navyBlue, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.navyBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topicCard(
      BuildContext context, TopicModel t, int number, Set<String> watched) {
    final hasVideo = t.hasVideo;
    final hasTest = t.questionCount > 0;
    final showCards = t.flashcardCount > 0;
    final isWatched = watched.contains('${subjectId}_${t.id}');

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // Тақырыпқа басқанда — видео + тақырыптық тест бір экранда ашылады.
        onTap: () {
          if (hasVideo || hasTest) {
            _openLesson(context, t);
          } else if (showCards) {
            _openFlashcards(context, t);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isWatched
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.divider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text('$number',
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(t.title,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  if (isWatched)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 20)
                  else if (hasVideo || hasTest)
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted, size: 22),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (hasVideo)
                    _metaBadge(Icons.ondemand_video_rounded, 'Видеосабақ',
                        const Color(0xFFC0392B)),
                  if (hasTest)
                    _metaBadge(Icons.quiz_rounded,
                        'Тақырыптық тест (${t.questionCount})',
                        AppColors.navyBlue),
                  if (showCards)
                    _actionChip(
                      context,
                      icon: Icons.style_rounded,
                      label: 'Флешкарта (${t.flashcardCount})',
                      bg: AppColors.gold,
                      fg: AppColors.navyDark,
                      onTap: () => _openFlashcards(context, t),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color bg,
    Color fg = AppColors.white,
    required VoidCallback onTap,
    bool locked = false,
  }) {
    if (locked) {
      // Оффлайн оқушыға — құлыпталған чип (басқанда түсіндірме).
      return ElevatedButton.icon(
        onPressed: () => _snack(context, 'Бұл онлайн оқушыларға қолжетімді'),
        icon: const Icon(Icons.lock_rounded, size: 16),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textMuted.withValues(alpha: 0.18),
          foregroundColor: AppColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
    );
  }

  /// Тақырыпты ашу — видео + тақырыптық тест бір экранда (VideoLessonScreen).
  void _openLesson(BuildContext context, TopicModel t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoLessonScreen(
          topicTitle: t.title,
          subjectTitle: subjectTitle,
          videoUrl: t.videoUrl,
          icon: icon,
          color: color,
          student: student,
          subjectId: subjectId,
          topicId: t.id,
        ),
      ),
    );
  }

  Widget _metaBadge(IconData icon, String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: c, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Future<void> _openFlashcards(BuildContext context, TopicModel t) async {
    _showLoading(context);
    List<FlashcardModel> cards;
    try {
      cards = await _content.getFlashcards(subjectId, t.id);
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      _snack(context, 'Карточкаларды жүктеу қатесі');
      return;
    }
    if (!context.mounted) return;
    Navigator.pop(context);
    if (cards.isEmpty) {
      _snack(context, 'Бұл тақырыпта карточка жоқ');
      return;
    }

    final deck = FlashcardDeck(
      id: t.id,
      subjectId: subjectId,
      title: t.title,
      icon: icon,
      color: color,
      isMandatory: false,
      cards: cards
          .map((c) => Flashcard(
                front: c.front,
                back: c.back,
                hint: c.hint,
                quizOptions: const [],
                correctIndex: 0,
              ))
          .toList(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FlashcardStudyScreen(deck: deck)),
    );
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.navyBlue)),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
