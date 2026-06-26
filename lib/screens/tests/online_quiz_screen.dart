// lib/screens/tests/online_quiz_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/question_model.dart';
import '../../services/content_service.dart';
import '../../utils/screen_secure.dart';

/// Оқушы Firestore-дағы сұрақтар банкінен онлайн тест тапсырады.
/// Нәтиже quizAttempts коллекциясына сақталады.
class OnlineQuizScreen extends StatefulWidget {
  final String subjectId;
  final String topicId;
  final String topicTitle;
  final List<QuestionModel> questions;
  final String studentId;
  final String studentName;
  final Color color;

  const OnlineQuizScreen({
    super.key,
    required this.subjectId,
    required this.topicId,
    required this.topicTitle,
    required this.questions,
    required this.studentId,
    required this.studentName,
    this.color = AppColors.navyBlue,
  });

  @override
  State<OnlineQuizScreen> createState() => _OnlineQuizScreenState();
}

class _OnlineQuizScreenState extends State<OnlineQuizScreen> {
  final _content = ContentService();
  int _index = 0;
  int? _selected;
  bool _showResult = false;
  int _correct = 0;
  bool _saved = false;
  bool _completed = false; // тест аяқталды — артқа еркін шығады

  @override
  void initState() {
    super.initState();
    ScreenSecure.enable(); // тест экранынан скриншот алуды бұғаттау
  }

  @override
  void dispose() {
    ScreenSecure.disable();
    super.dispose();
  }

  QuestionModel get _q => widget.questions[_index];
  bool get _isLast => _index == widget.questions.length - 1;

  void _submit() {
    if (_selected == null) return;
    setState(() {
      _showResult = true;
      if (_selected == _q.correctIndex) _correct++;
    });
  }

  void _next() {
    if (!_isLast) {
      setState(() {
        _index++;
        _selected = null;
        _showResult = false;
      });
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (!_saved) {
      _saved = true;
      try {
        await _content.saveQuizAttempt(
          studentId: widget.studentId,
          studentName: widget.studentName,
          subjectId: widget.subjectId,
          topicId: widget.topicId,
          topicTitle: widget.topicTitle,
          correct: _correct,
          total: widget.questions.length,
        );
      } catch (_) {
        // Сақтау сәтсіз болса да нәтижені көрсетеміз
      }
    }
    if (!mounted) return;
    setState(() => _completed = true);

    final total = widget.questions.length;
    final percent = total > 0 ? (_correct / total * 100).round() : 0;
    final Color color;
    final String emoji, message;
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
      message = 'Тағы жаттығыңыз';
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
              const SizedBox(height: 8),
              Text(message,
                  style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
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
                    Text('$_correct / $total',
                        style: TextStyle(
                            color: color,
                            fontSize: 36,
                            fontWeight: FontWeight.w900)),
                    Text('$percent% дұрыс',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w700)),
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
                          _index = 0;
                          _selected = null;
                          _showResult = false;
                          _correct = 0;
                          _saved = false;
                        });
                      },
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

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Тесттен шығу'),
        content: const Text('Шықсаңыз нәтиже сақталмайды. Шынымен шығасыз ба?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Жалғастыру')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Шығу'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_index + 1) / widget.questions.length;
    return PopScope(
      canPop: _completed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmExit();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.topicTitle),
        backgroundColor: AppColors.navyBlue,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${_index + 1} / ${widget.questions.length}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.navyBlue,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation(widget.color),
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
                        Text('$_correct',
                            style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.color, widget.color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
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
                      child: Text('СҰРАҚ · ${_q.points} ұпай',
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 12),
                    Text(_q.question,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: _q.options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _optionTile(i),
                ),
              ),
              if (_showResult && _q.explanation != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.navyBlue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                          color: AppColors.navyBlue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_q.explanation!,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showResult
                      ? _next
                      : (_selected != null ? _submit : null),
                  icon: Icon(
                    _showResult
                        ? (_isLast
                            ? Icons.flag_rounded
                            : Icons.arrow_forward_rounded)
                        : Icons.check_rounded,
                    size: 20,
                  ),
                  label: Text(
                    _showResult
                        ? (_isLast ? 'Аяқтау' : 'Келесі сұрақ')
                        : 'Жауапты тексеру',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
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
      ),
    );
  }

  Widget _optionTile(int i) {
    final isSelected = _selected == i;
    final isCorrect = i == _q.correctIndex;

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
      } else if (isSelected) {
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
      onTap: _showResult ? null : () => setState(() => _selected = i),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
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
                child: Text(String.fromCharCode(65 + i),
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_q.options[i],
                  style: TextStyle(
                      color: textColor,
                      fontWeight:
                          isSelected || icon != null ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14)),
            ),
            if (icon != null) Icon(icon, color: iconColor, size: 22),
          ],
        ),
      ),
    );
  }
}
