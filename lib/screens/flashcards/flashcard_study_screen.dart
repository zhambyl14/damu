// lib/screens/flashcards/flashcard_study_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import 'flashcards_screen.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final FlashcardDeck deck;
  const FlashcardStudyScreen({super.key, required this.deck});

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showBack = false;
  late AnimationController _flipCtrl;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showBack) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    setState(() => _showBack = !_showBack);
  }

  void _next() {
    if (_currentIndex < widget.deck.cards.length - 1) {
      setState(() {
        _currentIndex++;
        _showBack = false;
        _flipCtrl.reset();
      });
    } else {
      _showFinished();
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showBack = false;
        _flipCtrl.reset();
      });
    }
  }

  void _showFinished() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.celebration_rounded, color: AppColors.success),
            SizedBox(width: 10),
            Text('Жарайсыз!'),
          ],
        ),
        content: Text(
            'Барлық ${widget.deck.cards.length} карточканы қарап шықтыңыз.\n\nБілімді тексеру үшін Quiz режимін қолданыңыз.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _showBack = false;
                _flipCtrl.reset();
              });
            },
            child: const Text('Қайта бастау'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Шығу'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.deck.cards[_currentIndex];
    final progress = (_currentIndex + 1) / widget.deck.cards.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.deck.title),
        backgroundColor: AppColors.navyBlue,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Прогресс
              Row(
                children: [
                  Text(
                    '${_currentIndex + 1} / ${widget.deck.cards.length}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.navyBlue,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation(widget.deck.color),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Карточка
              Expanded(
                child: GestureDetector(
                  onTap: _flip,
                  child: AnimatedBuilder(
                    animation: _flipCtrl,
                    builder: (_, __) {
                      final rotate = _flipCtrl.value * 3.14159;
                      final isFlipped = _flipCtrl.value >= 0.5;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(rotate),
                        child: !isFlipped
                            ? _buildFront(card)
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(3.14159),
                                child: _buildBack(card),
                              ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Тап картаны айналдыру түсініктемесі
              Text(
                _showBack
                    ? 'Жасыру үшін басыңыз'
                    : 'Жауапты көру үшін басыңыз',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
              ),

              const SizedBox(height: 16),

              // Навигация батырмалары
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _currentIndex > 0 ? _prev : null,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Алдыңғы'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navyBlue,
                        side: const BorderSide(color: AppColors.navyBlue),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        _currentIndex == widget.deck.cards.length - 1
                            ? 'Аяқтау'
                            : 'Келесі',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyBlue,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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

  Widget _buildFront(Flashcard card) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.deck.color,
            widget.deck.color.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: widget.deck.color.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'СҰРАҚ',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.front,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (card.hint != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded,
                              color: AppColors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            card.hint!,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app_rounded,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                'Жауапты көру',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBack(Flashcard card) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.deck.color, width: 2),
        boxShadow: [
          BoxShadow(
            color: widget.deck.color.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: widget.deck.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'ЖАУАП',
              style: TextStyle(
                color: widget.deck.color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                card.back,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}