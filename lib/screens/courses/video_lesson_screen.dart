// lib/screens/courses/video_lesson_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../models/question_model.dart';
import '../../utils/screen_secure.dart';
import '../../services/content_service.dart';
import '../../services/video_progress_service.dart';

/// Тақырып сабағы: ҮСТінде видео, АСТында тақырыптық тест — бір экранда.
/// • Видео қосымша ішінде ойналады; скриншот/экран жазу бұғатталған (FLAG_SECURE).
class VideoLessonScreen extends StatefulWidget {
  final String topicTitle;
  final String subjectTitle;
  final String? videoUrl;
  final IconData icon;
  final Color color;
  final UserModel student;
  final String? subjectId;
  final String? topicId;

  const VideoLessonScreen({
    super.key,
    required this.topicTitle,
    required this.subjectTitle,
    required this.videoUrl,
    required this.icon,
    required this.color,
    required this.student,
    this.subjectId,
    this.topicId,
  });

  @override
  State<VideoLessonScreen> createState() => _VideoLessonScreenState();
}

class _VideoLessonScreenState extends State<VideoLessonScreen> {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _sub;
  String? _videoId;
  bool _marked = false;
  bool _embedError = false;

  // Тақырыптық тест.
  List<QuestionModel> _questions = [];
  bool _loadingTest = false;

  bool get _hasVideo =>
      widget.videoUrl != null && widget.videoUrl!.trim().isNotEmpty;
  bool get _canVideo => widget.student.canAccessVideoLessons;
  bool get _canTest => widget.student.canAccessTopicTests;

  @override
  void initState() {
    super.initState();
    ScreenSecure.enable();

    if (_hasVideo && _canVideo) {
      _videoId =
          YoutubePlayerController.convertUrlToId(widget.videoUrl!.trim());
      if (_videoId != null) {
        _controller = YoutubePlayerController.fromVideoId(
          videoId: _videoId!,
          autoPlay: false,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
            enableCaption: true,
            showVideoAnnotations: false,
            strictRelatedVideos: true,
            playsInline: true,
          ),
        );
        _sub = _controller!.stream.listen(_onPlayerUpdate);
      }
    }

    if (_canTest && widget.subjectId != null && widget.topicId != null) {
      _loadTest();
    }
  }

  Future<void> _loadTest() async {
    setState(() => _loadingTest = true);
    try {
      final qs = await ContentService()
          .getQuestions(widget.subjectId!, widget.topicId!);
      if (!mounted) return;
      setState(() {
        _questions = qs;
        _loadingTest = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTest = false);
    }
  }

  void _onPlayerUpdate(YoutubePlayerValue value) {
    if (!_embedError && value.error != YoutubeError.none) {
      setState(() => _embedError = true);
      return;
    }
    if (_marked) return;
    if (value.playerState == PlayerState.playing) {
      _marked = true;
      if (widget.student.isStudent &&
          widget.subjectId != null &&
          widget.topicId != null) {
        VideoProgressService()
            .markWatched(widget.student.uid, widget.subjectId!, widget.topicId!);
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller?.close();
    ScreenSecure.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      return YoutubePlayerScaffold(
        controller: controller,
        aspectRatio: 16 / 9,
        builder: (context, player) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: _appBar(),
          body: _content(videoWidget: _embedError
              ? _lockedBanner(
                  'Бұл видеоны қосымшада ойнату мүмкін емес (иесі ендіруге тыйым салған).')
              : AspectRatio(aspectRatio: 16 / 9, child: player)),
        ),
      );
    }
    // Видеосыз (немесе оффлайн/жарамсыз сілтеме) — тек мәтін + тест.
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(),
      body: _content(videoWidget: _videoPlaceholder()),
    );
  }

  AppBar _appBar() => AppBar(
        title: Text(widget.subjectTitle),
        backgroundColor: AppColors.navyBlue,
      );

  Widget _content({required Widget videoWidget}) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        videoWidget,
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.topicTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Row(children: [
                Icon(widget.icon, size: 16, color: widget.color),
                const SizedBox(width: 6),
                Text(widget.subjectTitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 16),
              _protectionNote(),
              const SizedBox(height: 20),
              _testSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _videoPlaceholder() {
    if (!_hasVideo) return const SizedBox.shrink();
    if (!_canVideo) {
      return _lockedBanner('Видеосабақ онлайн оқушыларға қолжетімді.');
    }
    return _lockedBanner(
        'Бұл видеоны қосымшада ойнату мүмкін емес (иесі ендіруге тыйым салған).');
  }

  // ── Тақырыптық тест (видео астында) ──────────────────────────────────────────
  Widget _testSection() {
    final hasTopic = widget.subjectId != null && widget.topicId != null;
    if (!hasTopic) return const SizedBox.shrink();

    if (!_canTest) {
      return _lockedBanner('Тақырыптық тест онлайн оқушыларға қолжетімді.');
    }
    if (_loadingTest) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.navyBlue)),
      );
    }
    if (_questions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.quiz_rounded, color: AppColors.navyBlue, size: 20),
          const SizedBox(width: 8),
          Text('Тақырыптық тест',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.navyBlue, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${_questions.length} сұрақ',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 12),
        _InlineTopicTest(
          questions: _questions,
          studentId: widget.student.uid,
          studentName: widget.student.name,
          subjectId: widget.subjectId!,
          topicId: widget.topicId!,
          topicTitle: widget.topicTitle,
          color: widget.color,
        ),
      ],
    );
  }

  Widget _protectionNote() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.shield_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Бұл материал қорғалған: скриншот, экран жазу және бөлісу шектелген. '
              'Видео тек осы қосымшада қолжетімді.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ]),
      );

  Widget _lockedBanner(String msg) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(children: [
          const Icon(Icons.lock_rounded, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary, height: 1.4)),
          ),
        ]),
      );
}

/// Видео астындағы инлайн тақырыптық тест (нәтиже quizattempts-қа сақталады).
class _InlineTopicTest extends StatefulWidget {
  final List<QuestionModel> questions;
  final String studentId;
  final String studentName;
  final String subjectId;
  final String topicId;
  final String topicTitle;
  final Color color;

  const _InlineTopicTest({
    required this.questions,
    required this.studentId,
    required this.studentName,
    required this.subjectId,
    required this.topicId,
    required this.topicTitle,
    required this.color,
  });

  @override
  State<_InlineTopicTest> createState() => _InlineTopicTestState();
}

class _InlineTopicTestState extends State<_InlineTopicTest> {
  int _index = 0;
  int? _selected;
  bool _showResult = false;
  int _correct = 0;
  bool _finished = false;
  bool _saved = false;

  QuestionModel get _q => widget.questions[_index];
  bool get _isLast => _index == widget.questions.length - 1;

  void _check() {
    if (_selected == null) return;
    setState(() {
      _showResult = true;
      if (_selected == _q.correctIndex) _correct++;
    });
  }

  Future<void> _next() async {
    if (!_isLast) {
      setState(() {
        _index++;
        _selected = null;
        _showResult = false;
      });
      return;
    }
    setState(() => _finished = true);
    if (!_saved) {
      _saved = true;
      try {
        await ContentService().saveQuizAttempt(
          studentId: widget.studentId,
          studentName: widget.studentName,
          subjectId: widget.subjectId,
          topicId: widget.topicId,
          topicTitle: widget.topicTitle,
          correct: _correct,
          total: widget.questions.length,
        );
      } catch (_) {}
    }
  }

  void _restart() {
    setState(() {
      _index = 0;
      _selected = null;
      _showResult = false;
      _correct = 0;
      _finished = false;
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _resultCard();

    final total = widget.questions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('${_index + 1} / $total',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.navyBlue, fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_index + 1) / total,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation(widget.color),
                minHeight: 6,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.navyBlue.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(_q.question,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(height: 1.4)),
        ),
        const SizedBox(height: 12),
        ...List.generate(_q.options.length, (i) => _option(i)),
        const SizedBox(height: 4),
        if (_showResult && _q.explanation != null && _q.explanation!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navyBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.navyBlue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_q.explanation!,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
            ]),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showResult
                ? _next
                : (_selected != null ? _check : null),
            icon: Icon(
                _showResult
                    ? (_isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded)
                    : Icons.check_rounded,
                size: 20),
            label: Text(
                _showResult
                    ? (_isLast ? 'Аяқтау' : 'Келесі сұрақ')
                    : 'Жауапты тексеру',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navyBlue,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              disabledBackgroundColor: AppColors.navyBlue.withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _option(int i) {
    final isSelected = _selected == i;
    final isCorrect = i == _q.correctIndex;
    Color border = AppColors.divider;
    Color bg = AppColors.white;
    Color text = AppColors.textPrimary;
    IconData? icon;
    if (_showResult) {
      if (isCorrect) {
        border = AppColors.success;
        bg = AppColors.success.withValues(alpha: 0.08);
        text = AppColors.success;
        icon = Icons.check_circle_rounded;
      } else if (isSelected) {
        border = AppColors.error;
        bg = AppColors.error.withValues(alpha: 0.08);
        text = AppColors.error;
        icon = Icons.cancel_rounded;
      }
    } else if (isSelected) {
      border = AppColors.navyBlue;
      bg = AppColors.navyBlue.withValues(alpha: 0.06);
      text = AppColors.navyBlue;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _showResult ? null : () => setState(() => _selected = i),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: border.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(String.fromCharCode(65 + i),
                    style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_q.options[i],
                  style: TextStyle(
                      color: text,
                      fontWeight:
                          isSelected || icon != null ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14)),
            ),
            if (icon != null) Icon(icon, color: text, size: 22),
          ]),
        ),
      ),
    );
  }

  Widget _resultCard() {
    final total = widget.questions.length;
    final percent = total > 0 ? (_correct / total * 100).round() : 0;
    final Color c = percent >= 70
        ? AppColors.success
        : (percent >= 50 ? AppColors.warning : AppColors.error);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(percent >= 70 ? '🎉' : '📊', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 6),
          Text('$_correct / $total дұрыс',
              style: TextStyle(
                  color: c, fontSize: 22, fontWeight: FontWeight.w900)),
          Text('$percent%',
              style: TextStyle(color: c, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Қайталау'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navyBlue,
                side: const BorderSide(color: AppColors.navyBlue),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
