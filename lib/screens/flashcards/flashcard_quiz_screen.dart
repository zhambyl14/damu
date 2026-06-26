// lib/screens/flashcards/flashcard_quiz_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../utils/screen_secure.dart';
import 'flashcards_screen.dart';

class FlashcardQuizScreen extends StatefulWidget {
  final FlashcardDeck deck;
  const FlashcardQuizScreen({super.key, required this.deck});

  @override
  State<FlashcardQuizScreen> createState() => _FlashcardQuizScreenState();
}

class _FlashcardQuizScreenState extends State<FlashcardQuizScreen> {
  int _currentIndex = 0;
  int? _selectedOption;
  bool _showResult = false;
  int _correctCount = 0;
  final List<bool> _answers = []; // әр сұраққа дұрыс/қате

  @override
  void initState() {
    super.initState();
    ScreenSecure.enable(); // quiz экранынан скриншот алуды бұғаттау
  }

  @override
  void dispose() {
    ScreenSecure.disable();
    super.dispose();
  }

  void _selectOption(int idx) {
    if (_showResult) return;
    setState(() {
      _selectedOption = idx;
    });
  }

  void _submitAnswer() {
    if (_selectedOption == null) return;
    final card = widget.deck.cards[_currentIndex];
    final isCorrect = _selectedOption == card.correctIndex;
    setState(() {
      _showResult = true;
      if (isCorrect) _correctCount++;
      _answers.add(isCorrect);
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.deck.cards.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _showResult = false;
      });
    } else {
      _showFinalResult();
    }
  }

  void _showFinalResult() {
    final total = widget.deck.cards.length;
    final percent = (_correctCount / total * 100).round();
    final Color color;
    final String emoji;
    final String message;

    if (percent >= 90) {
      color = AppColors.success;
      emoji = '🏆';
      message = 'Керемет!';
    } else if (percent >= 70) {
      color = AppColors.gold;
      emoji = '⭐';
      message = 'Жақсы!';
    } else if (percent >= 50) {
      color = AppColors.warning;
      emoji = '👍';
      message = 'Орташа';
    } else {
      color = AppColors.error;
      emoji = '💪';
      message = 'Жаттай беріңіз';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(message,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$_correctCount',
                            style: TextStyle(
                              color: color,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            )),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('/ $total',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ],
                    ),
                    Text('$percent% дұрыс',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _currentIndex = 0;
                          _selectedOption = null;
                          _showResult = false;
                          _correctCount = 0;
                          _answers.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Қайталау'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyBlue,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Шығу'),
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

  @override
  Widget build(BuildContext context) {
    final card = widget.deck.cards[_currentIndex];
    final progress = (_currentIndex + 1) / widget.deck.cards.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Quiz — ${widget.deck.title}'),
        backgroundColor: AppColors.navyBlue,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Прогресс және ұпай
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
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded,
                            color: AppColors.success, size: 14),
                        const SizedBox(width: 4),
                        Text('$_correctCount',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Сұрақ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.deck.color,
                      widget.deck.color.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: widget.deck.color.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 12),
                    Text(
                      card.front,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Жауап нұсқалары
              Expanded(
                child: ListView.separated(
                  itemCount: card.quizOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final isSelected = _selectedOption == i;
                    final isCorrect = i == card.correctIndex;

                    Color borderColor = AppColors.divider;
                    Color bgColor = AppColors.white;
                    Color textColor = AppColors.textPrimary;
                    IconData? icon;
                    Color? iconColor;

                    if (_showResult) {
                      if (isCorrect) {
                        borderColor = AppColors.success;
                        bgColor = AppColors.success.withValues(alpha: 0.08);
                        textColor = AppColors.success;
                        icon = Icons.check_circle_rounded;
                        iconColor = AppColors.success;
                      } else if (isSelected && !isCorrect) {
                        borderColor = AppColors.error;
                        bgColor = AppColors.error.withValues(alpha: 0.08);
                        textColor = AppColors.error;
                        icon = Icons.cancel_rounded;
                        iconColor = AppColors.error;
                      }
                    } else if (isSelected) {
                      borderColor = AppColors.navyBlue;
                      bgColor = AppColors.navyBlue.withValues(alpha: 0.06);
                      textColor = AppColors.navyBlue;
                    }

                    return InkWell(
                      onTap: () => _selectOption(i),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: borderColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + i), // A, B, C, D
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                card.quizOptions[i],
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: isSelected || (icon != null)
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (icon != null)
                              Icon(icon, color: iconColor, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Жауап түсіндірмесі (нәтиже көрсетілгенде)
              if (_showResult) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.navyBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                          color: AppColors.navyBlue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          card.back,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Әрекет батырмасы
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showResult
                      ? _nextQuestion
                      : (_selectedOption != null ? _submitAnswer : null),
                  icon: Icon(
                    _showResult
                        ? (_currentIndex == widget.deck.cards.length - 1
                            ? Icons.flag_rounded
                            : Icons.arrow_forward_rounded)
                        : Icons.check_rounded,
                    size: 20,
                  ),
                  label: Text(
                    _showResult
                        ? (_currentIndex == widget.deck.cards.length - 1
                            ? 'Аяқтау'
                            : 'Келесі сұрақ')
                        : 'Жауапты тексеру',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor:
                        AppColors.navyBlue.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}