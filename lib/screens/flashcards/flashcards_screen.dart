// lib/screens/flashcards/flashcards_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../models/flashcard_model.dart';
import '../../data/subjects_catalog.dart';
import '../../providers/auth_provider.dart';
import '../../services/content_service.dart';
import 'flashcard_study_screen.dart';
import 'flashcard_quiz_screen.dart';

class FlashcardDeck {
  final String id;
  final String subjectId;
  final String title;
  final IconData icon;
  final Color color;
  final List<Flashcard> cards;
  final bool isMandatory;

  const FlashcardDeck({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.icon,
    required this.color,
    required this.cards,
    required this.isMandatory,
  });
}

class Flashcard {
  final String front;
  final String back;
  final String? hint;
  // Quiz үшін жауап нұсқалары
  final List<String> quizOptions;
  final int correctIndex;

  const Flashcard({
    required this.front,
    required this.back,
    this.hint,
    required this.quizOptions,
    required this.correctIndex,
  });
}

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final _content = ContentService();
  late Future<List<FlashcardDeck>> _future;
  String? _loadedFor;

  /// Базадан оқушының пәндері бойынша флешкарталарды жүктеп, дека жасайды.
  /// Әр пәнге — бір дека (тақырыптардың карточкалары жинақталады).
  /// Quiz нұсқалары басқа карточкалардың артынан кездейсоқ жасалады.
  Future<List<FlashcardDeck>> _loadDecks(UserModel user) async {
    final subjectIds = <String>[
      ...SubjectCatalog.mandatoryIds,
      ...user.electiveSubjectIds,
    ];
    final rng = Random();
    final decks = <FlashcardDeck>[];

    for (final sid in subjectIds) {
      final cat = SubjectCatalog.byId(sid);
      if (cat == null) continue;

      final topics = await _content.getTopics(sid);
      final models = <FlashcardModel>[];
      for (final t in topics) {
        models.addAll(await _content.getFlashcards(sid, t.id));
      }
      if (models.isEmpty) continue;

      final allBacks = models.map((m) => m.back).toSet().toList();
      final cards = models.map((m) {
        final distractors = allBacks.where((b) => b != m.back).toList()
          ..shuffle(rng);
        final opts = <String>[m.back, ...distractors.take(3)]..shuffle(rng);
        return Flashcard(
          front: m.front,
          back: m.back,
          hint: m.hint,
          quizOptions: opts,
          correctIndex: opts.indexOf(m.back),
        );
      }).toList();

      decks.add(FlashcardDeck(
        id: sid,
        subjectId: sid,
        title: cat.title,
        icon: cat.icon,
        color: cat.color,
        cards: cards,
        isMandatory: cat.isMandatory,
      ));
    }
    return decks;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const SizedBox.shrink();

    // Пайдаланушы (немесе оның пәндері) өзгерсе — қайта жүктеу.
    final key = '${user.uid}|${user.electiveSubjectIds.join(",")}';
    if (_loadedFor != key) {
      _loadedFor = key;
      _future = _loadDecks(user);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Карточкалар'),
        backgroundColor: AppColors.navyBlue,
        elevation: 0,
      ),
      body: FutureBuilder<List<FlashcardDeck>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }
          final decks = snap.data ?? [];
          final totalCards = decks.fold<int>(0, (s, d) => s + d.cards.length);

          return RefreshIndicator(
            color: AppColors.navyBlue,
            onRefresh: () async {
              setState(() => _future = _loadDecks(user));
              await _future;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MiniStat(
                        label: 'Барлық карточка',
                        value: '$totalCards',
                        icon: Icons.style_rounded,
                        color: AppColors.navyBlue,
                      ),
                      const SizedBox(width: 10),
                      _MiniStat(
                        label: 'Декалар',
                        value: '${decks.length}',
                        icon: Icons.layers_rounded,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 10),
                      _MiniStat(
                        label: 'Пәндер',
                        value: '${decks.length}',
                        icon: Icons.book_rounded,
                        color: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (decks.isEmpty)
                    _emptyState(context)
                  else ...[
                    Text(
                      'Менің декаларым',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.navyBlue,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: decks.length,
                      itemBuilder: (context, i) => _DeckCard(deck: decks[i]),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Icon(Icons.style_outlined,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text('Карточкалар әзірленуде',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Text('Оқытушылар тақырыптарға флешкарта қосқан соң осында көрінеді',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    )),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  final FlashcardDeck deck;
  const _DeckCard({required this.deck});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _showActions(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: deck.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(deck.icon, color: deck.color, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (deck.isMandatory
                              ? AppColors.navyBlue
                              : AppColors.gold)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      deck.isMandatory ? 'Мінд.' : 'Таңд.',
                      style: TextStyle(
                        color: deck.isMandatory
                            ? AppColors.navyBlue
                            : AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                deck.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.style_rounded, color: deck.color, size: 14),
                  const SizedBox(width: 4),
                  Text('${deck.cards.length} карточка',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: deck.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(deck.icon, color: deck.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deck.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('${deck.cards.length} карточка',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _ActionTile(
              icon: Icons.school_rounded,
              title: 'Карточкаларды оқу',
              subtitle: 'Бір-бірлеп жаттау',
              color: AppColors.navyBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlashcardStudyScreen(deck: deck),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.quiz_rounded,
              title: 'Quiz режимі',
              subtitle: 'Білімді тексеру',
              color: AppColors.gold,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlashcardQuizScreen(deck: deck),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}
