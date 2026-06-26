// lib/screens/tests/mock_test_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../models/score_model.dart';
import '../../models/mock_test_model.dart';
import '../../services/question_bank_service.dart';
import '../../services/score_service.dart';
import '../../services/mock_draft_service.dart';
import '../../utils/screen_secure.dart';
import '../../utils/refresh_guard.dart';

/// Оқушы ҰБТ тестін тапсырады. Тест банктен толық ҰБТ структурасы бойынша
/// генерацияланады (әр оқушыға жеке, бұрын көрмеген сұрақтардан).
///
/// Екі режим:
///   • Айлық мок (mock != null) — рейтингке жазылады (scores, testType 'mock').
///   • Дайындық (practice) — тек өзі үшін, рейтингке ӘСЕР ЕТПЕЙДІ.
///
/// UX (ҰБТ / Pearson · ETS деңгейіндегі тәжірибе):
///   • Пәндік навигация — үлкен header, пәндер арасында еркін ауысу.
///   • Сұрақтар картасы — әр сұрақтың күйі (жауап берілді / flag / қазіргі).
///   • Прогресс-бар + статистика (жауап берілді / қалды / flag).
///   • 240 минуттық таймер — соңында сары → қызыл, біткенде авто-тапсыру.
///   • Тапсыру алдында толық summary, шығу мен жаңартудан қорғау.
class MockTestScreen extends StatefulWidget {
  final MockTest? mock;
  final UserModel student;
  final bool practice;

  const MockTestScreen({super.key, required this.mock, required this.student})
      : practice = false;

  const MockTestScreen.practice({super.key, required this.student})
      : mock = null,
        practice = true;

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

/// Бір пән (бөлім) — header мен навигатор үшін топ.
class _SubjectGroup {
  final String key;
  final String label;
  final IconData icon;
  final List<int> indices; // осы пәнге тиесілі ГЛОБАЛДЫ сұрақ индекстері
  _SubjectGroup(this.key, this.label, this.icon, this.indices);
}

class _MockTestScreenState extends State<MockTestScreen> {
  final _bank = QuestionBankService();
  final _scoreService = ScoreService();
  final _draftService = MockDraftService();

  bool _loading = true;
  String? _error;
  List<MockQuestion> _questions = [];
  List<_SubjectGroup> _groups = [];

  int _index = 0;
  // Сұрақ индексі → таңдалған нұсқа индекстері (бірден тексеру жоқ).
  final Map<int, Set<int>> _answers = {};
  // Flag қойылған сұрақтар (кейін қайта қарау үшін).
  final Set<int> _flagged = {};

  bool _finishing = false;
  bool _saved = false;
  bool _completed = false; // аяқталды (нәтиже шықты) — енді артқа шығуға болады

  // bucket → барлық балл (генерация кезінде есептеледі).
  final Map<String, int> _totalPoints = {};

  // ── Таймер ────────────────────────────────────────────────────────────────
  static const _testDuration = Duration(minutes: 240); // ҰБТ — 240 минут
  Timer? _timer;
  Duration _remaining = _testDuration;
  bool _blink = false; // соңғы 5 минутта жыпылықтау

  final ScrollController _stripCtrl = ScrollController();

  // Авто-сақтау (draft) — өзгерістерді debounce-пен жазады.
  Timer? _saveDebounce;
  String get _mockKey => widget.mock?.id ?? 'practice';

  String get _title => widget.practice ? 'Дайындық тесті' : widget.mock!.title;

  @override
  void initState() {
    super.initState();
    ScreenSecure.enable();
    RefreshGuard.enable(); // web: байқаусыз F5/refresh-тен қорғау
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveDebounce?.cancel();
    _stripCtrl.dispose();
    ScreenSecure.disable();
    RefreshGuard.disable();
    super.dispose();
  }

  String _bucket(MockQuestion q) =>
      q.section == MockSection.elective ? (q.subjectId ?? 'elective') : q.section;

  Future<void> _load() async {
    try {
      // 1) Аяқталмаған draft бар ма — болса, жалғастыруды ұсынамыз.
      final restored = await _tryRestoreDraft();

      // 2) Қалпына келмесе — жаңа тест генерациялаймыз.
      if (!restored) {
        final gen = await _bank.generateUntTest(widget.student,
            mockId: _mockKey);
        if (gen.isEmpty) {
          setState(() {
            _error = 'Банкте бұл тестке жеткілікті сұрақ жоқ. '
                'Әкімші сұрақтар банкін толтыруы керек.';
            _loading = false;
          });
          return;
        }
        _questions = gen.questions;
      }

      for (final q in _questions) {
        _totalPoints[_bucket(q)] = (_totalPoints[_bucket(q)] ?? 0) + q.points;
      }
      setState(() {
        _groups = _buildGroups(_questions);
        _loading = false;
      });
      _startTimer();
      if (restored) _scrollStrip();
    } catch (e) {
      setState(() {
        _error = 'Сұрақтарды жүктеу қатесі: $e';
        _loading = false;
      });
    }
  }

  /// Сақталған draft болса, оқушыдан сұрап, тестті дәл сол күйде қалпына келтіреді.
  /// true — қалпына келді; false — draft жоқ / бас тартты / сәйкессіз.
  Future<bool> _tryRestoreDraft() async {
    Map<String, dynamic>? draft;
    try {
      draft = await _draftService.load(widget.student.uid, _mockKey);
    } catch (_) {
      return false; // draft жүктеу қатесі — кедергі келтірмейміз
    }
    final rawIds = draft?['question_ids'];
    if (rawIds is! List || rawIds.isEmpty) return false;

    if (!mounted) return false;
    final resume = await _askResume(draft!['updated_at']);
    if (resume != true) {
      // Бас тартты — ескі draft-ты өшіреміз де, жаңа тест жасаймыз.
      try {
        await _draftService.clear(widget.student.uid, _mockKey);
      } catch (_) {}
      return false;
    }

    final ids = rawIds.map((e) => e.toString()).toList();
    final qs = await _bank.fetchByIds(ids, _mockKey);
    if (qs.length != ids.length || qs.isEmpty) {
      // Сұрақтар банкі өзгерген (өшірілген) — қалпына келтіру мүмкін емес.
      try {
        await _draftService.clear(widget.student.uid, _mockKey);
      } catch (_) {}
      return false;
    }
    _questions = qs;

    // Жауаптар: {"индекс": [нұсқалар]}
    final ans = draft['answers'];
    if (ans is Map) {
      ans.forEach((k, v) {
        final idx = int.tryParse(k.toString());
        if (idx != null && v is List) {
          _answers[idx] = v.map((e) => (e as num).toInt()).toSet();
        }
      });
    }
    // Flag индекстері
    final fl = draft['flagged'];
    if (fl is List) {
      _flagged.addAll(fl.map((e) => (e as num).toInt()));
    }
    // Соңғы ашық сұрақ
    final ci = (draft['current_index'] as num?)?.toInt() ?? 0;
    _index = (ci >= 0 && ci < _questions.length) ? ci : 0;
    // Қалған уақыт
    final rem = (draft['remaining_seconds'] as num?)?.toInt();
    if (rem != null && rem > 0) {
      _remaining = Duration(seconds: rem.clamp(0, _testDuration.inSeconds));
    }
    return true;
  }

  Future<bool?> _askResume(dynamic updatedAtRaw) {
    String when = '';
    final dt = updatedAtRaw is String ? DateTime.tryParse(updatedAtRaw) : null;
    if (dt != null) {
      final l = dt.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      when = '${two(l.day)}.${two(l.month)} ${two(l.hour)}:${two(l.minute)}';
    }
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.restore_rounded, color: AppColors.navyBlue),
          SizedBox(width: 8),
          Expanded(child: Text('Аяқталмаған тест')),
        ]),
        content: Text(
          'Сізде аяқталмаған тест бар${when.isNotEmpty ? ' ($when)' : ''}.\n\n'
          'Сол жерден жалғастырасыз ба, әлде жаңадан бастайсыз ба?',
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Жаңадан')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,
                foregroundColor: AppColors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Жалғастыру'),
          ),
        ],
      ),
    );
  }

  // ── Авто-сақтау ────────────────────────────────────────────────────────────
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), _saveDraft);
  }

  void _saveDraft() {
    if (_completed || _finishing || _questions.isEmpty) return;
    _draftService
        .save(
          studentId: widget.student.uid,
          mockKey: _mockKey,
          questionIds: _questions.map((q) => q.id).toList(),
          answers: _answers,
          flagged: _flagged,
          remainingSeconds: _remaining.inSeconds,
          currentIndex: _index,
        )
        .catchError((_) {}); // желі үзілсе — үнсіз, келесі өзгерісте қайта тырысады
  }

  List<_SubjectGroup> _buildGroups(List<MockQuestion> qs) {
    final groups = <_SubjectGroup>[];
    final idxByKey = <String, int>{};
    for (var i = 0; i < qs.length; i++) {
      final q = qs[i];
      final key = _bucket(q);
      if (!idxByKey.containsKey(key)) {
        idxByKey[key] = groups.length;
        groups.add(_SubjectGroup(key, _subjectLabel(q), _subjectIcon(q), []));
      }
      groups[idxByKey[key]!].indices.add(i);
    }
    return groups;
  }

  String _subjectLabel(MockQuestion q) {
    if (q.section == MockSection.elective) {
      return widget.student.electiveSubjects
          .firstWhere((e) => e.id == q.subjectId,
              orElse: () => const ElectiveSubject('', 'Таңдау пәні'))
          .label;
    }
    return MockSection.label(q.section);
  }

  IconData _subjectIcon(MockQuestion q) {
    if (q.section != MockSection.elective) {
      switch (q.section) {
        case MockSection.kazakhHistory:
          return Icons.account_balance_rounded;
        case MockSection.mathLiteracy:
          return Icons.calculate_rounded;
        case MockSection.readingLiteracy:
          return Icons.menu_book_rounded;
      }
    }
    switch (q.subjectId) {
      case 'mathematics':
        return Icons.functions_rounded;
      case 'physics':
        return Icons.bolt_rounded;
      case 'informatics':
        return Icons.computer_rounded;
      case 'biology':
        return Icons.eco_rounded;
      case 'chemistry':
        return Icons.science_rounded;
      case 'geography':
        return Icons.public_rounded;
      case 'world_history':
        return Icons.history_edu_rounded;
      case 'foreign':
      case 'english':
        return Icons.translate_rounded;
      case 'kazakh_language':
      case 'russian_language':
        return Icons.record_voice_over_rounded;
      case 'kazakh_literature':
      case 'russian_literature':
        return Icons.auto_stories_rounded;
      default:
        return Icons.school_rounded;
    }
  }

  // ── Геттерлер ──────────────────────────────────────────────────────────────
  MockQuestion get _q => _questions[_index];
  bool get _isLast => _index == _questions.length - 1;
  Set<int> get _sel => _answers[_index] ??= <int>{};
  int get _answeredCount => _answers.values.where((s) => s.isNotEmpty).length;
  int get _remainingCount => _questions.length - _answeredCount;

  _SubjectGroup get _currentGroup => _groups.firstWhere(
      (g) => g.indices.contains(_index),
      orElse: () => _groups.first);

  int _answeredIn(_SubjectGroup g) =>
      g.indices.where((i) => _answers[i]?.isNotEmpty ?? false).length;

  bool _isAnswered(int i) => _answers[i]?.isNotEmpty ?? false;

  // ── Таймер ──────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        t.cancel();
        setState(() => _remaining = Duration.zero);
        _autoSubmit();
        return;
      }
      setState(() {
        _remaining = next;
        if (_remaining.inMinutes < 5) _blink = !_blink;
      });
      // Қалған уақытты мезгіл-мезгіл сақтаймыз (желі үзілсе де таймер дәл болады).
      if (_remaining.inSeconds % 20 == 0) _saveDraft();
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _autoSubmit() async {
    if (_completed || _finishing) return;
    _snack('Уақыт бітті — тест автоматты түрде тапсырылды.');
    await _finish();
  }

  // ── Навигация ──────────────────────────────────────────────────────────────
  void _toggleOption(int i) {
    setState(() {
      final sel = _sel;
      if (_q.isMultiple) {
        sel.contains(i) ? sel.remove(i) : sel.add(i);
      } else {
        sel
          ..clear()
          ..add(i);
      }
    });
    _scheduleSave();
  }

  void _toggleFlag() {
    setState(() {
      _flagged.contains(_index)
          ? _flagged.remove(_index)
          : _flagged.add(_index);
    });
    _scheduleSave();
  }

  void _goTo(int i) {
    if (i < 0 || i >= _questions.length || i == _index) return;
    setState(() => _index = i);
    _scrollStrip();
    _scheduleSave();
  }

  void _go(int delta) => _goTo(_index + delta);

  void _jumpToSubject(_SubjectGroup g) {
    final target = g.indices.firstWhere((i) => !_isAnswered(i),
        orElse: () => g.indices.first);
    _goTo(target);
  }

  void _scrollStrip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_stripCtrl.hasClients) return;
      final pos = _currentGroup.indices.indexOf(_index);
      if (pos < 0) return;
      const itemExtent = 52.0;
      final target = (pos * itemExtent - 120)
          .clamp(0.0, _stripCtrl.position.maxScrollExtent);
      _stripCtrl.animateTo(target,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  // ── Аяқтау ──────────────────────────────────────────────────────────────
  Future<void> _onFinishPressed() async {
    final proceed = await _showReviewSheet();
    if (proceed != true) return;
    final confirmed = await _mathConfirm();
    if (confirmed == true) await _finish();
  }

  /// Артқа басқанда: режимге қарай шығу/тапсыруды растау.
  Future<void> _handleBackPress() async {
    if (_finishing || _completed) return;

    if (widget.practice) {
      final action = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Expanded(child: Text('Назар аударыңыз')),
          ]),
          content: const Text(
              'Тесттен шықсаңыз, сіздің нәтижеңіз сақталмайды.\n\n'
              'Тестті аяқтайсыз ба, әлде шығасыз ба?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Қалу')),
            TextButton(
                onPressed: () => Navigator.pop(context, 'finish'),
                child: const Text('Аяқтау')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, 'exit'),
              child: const Text('Шығу'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == 'exit') {
        Navigator.pop(context); // imperative pop — PopScope бұғаттамайды
      } else if (action == 'finish') {
        await _onFinishPressed();
      }
      return;
    }

    // ── Айлық мок: шықсаң — қазіргі жауаптармен авто-тапсырылады ──
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error),
          SizedBox(width: 8),
          Expanded(child: Text('Мок тесттен шығу')),
        ]),
        content: const Text(
          'Егер дәл қазір шықсаңыз:\n\n'
          '• Барлық жауап берген сұрақтарыңыз есептеледі.\n'
          '• Жауап берілмеген сұрақтарға автоматты түрде 0 балл қойылады.\n'
          '• Қайта жалғастыру МҮМКІН БОЛМАЙДЫ.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Қалу')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Шығып, тапсыру'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) await _finish();
  }

  /// Қарапайым математикалық растау (1+1 секілді). Дұрыс болса ғана аяқталады.
  Future<bool?> _mathConfirm() {
    final rng = Random();
    final a = 1 + rng.nextInt(8);
    final b = 1 + rng.nextInt(8);
    final ctrl = TextEditingController();
    String? err;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Тестті аяқтау'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Шынымен аяқтағыңыз келе ме?\n'
                  'Растау үшін есепті шығарыңыз:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Text('$a + $b = ?',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navyBlue)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Жауабы',
                  errorText: err,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Болдырмау')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  foregroundColor: AppColors.white),
              onPressed: () {
                if (int.tryParse(ctrl.text.trim()) == a + b) {
                  Navigator.pop(context, true);
                } else {
                  setLocal(() => err = 'Қате, қайта көріңіз');
                }
              },
              child: const Text('Аяқтау'),
            ),
          ],
        ),
      ),
    );
  }

  int _sectionScore(String bucket, int max) {
    final total = _totalPoints[bucket] ?? 0;
    if (total == 0) return 0;
    var earned = 0;
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (_bucket(q) != bucket) continue;
      final sel = _answers[i] ?? const <int>{};
      final correct = q.correctIndices.toSet();
      if (sel.length == correct.length && sel.containsAll(correct)) {
        earned += q.points;
      }
    }
    return ((earned / total) * max).round().clamp(0, max);
  }

  Future<void> _finish() async {
    if (_completed || _finishing) return;
    _timer?.cancel();
    setState(() => _finishing = true);
    final electives = widget.student.electiveSubjects;
    final e1Id = electives.isNotEmpty ? electives[0].id : null;
    final e2Id = electives.length > 1 ? electives[1].id : null;

    final score = ScoreModel(
      id: '',
      studentId: widget.student.uid,
      studentName: widget.student.name,
      className: widget.student.className,
      curatorId: widget.student.curatorId ?? '',
      date: DateTime.now(),
      testType: widget.practice ? 'practice' : 'mock',
      testName: widget.mock?.title ?? 'Дайындық тесті',
      mockId: widget.mock?.id, // айлық мок болса — бір рет қана тапсыру үшін

      kazakhHistory:
          _sectionScore(MockSection.kazakhHistory, ScoreModel.maxKazakhHistory),
      readingLiteracy: _sectionScore(
          MockSection.readingLiteracy, ScoreModel.maxReadingLiteracy),
      mathLiteracy:
          _sectionScore(MockSection.mathLiteracy, ScoreModel.maxMathLiteracy),
      elective1: e1Id != null ? _sectionScore(e1Id, ScoreModel.maxElective) : 0,
      elective2: e2Id != null ? _sectionScore(e2Id, ScoreModel.maxElective) : 0,
      elective1Name: electives.isNotEmpty ? electives[0].label : null,
      elective2Name: electives.length > 1 ? electives[1].label : null,
    );

    if (!_saved) {
      _saved = true;
      try {
        // Дайындық тесті рейтингке ЖАЗЫЛМАЙДЫ.
        if (!widget.practice) await _scoreService.addScore(score);
        // Көрген сұрақтарды белгілеу (қайталанбауы үшін — практика да санайды).
        await _bank.markSeen(
            widget.student.uid, _questions.map((q) => q.id).toList());
        // Тапсырылды — draft өшеді (қайта жалғастыру болмайды).
        await _draftService.clear(widget.student.uid, _mockKey);
      } catch (_) {}
    }
    RefreshGuard.disable(); // аяқталды — refresh ескертуі қажет емес
    if (!mounted) return;
    setState(() {
      _finishing = false;
      _completed = true; // аяқталды — енді артқа шығуға рұқсат
    });
    _showResultDialog(score);
  }

  void _showResultDialog(ScoreModel score) {
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
              Text(score.totalScore >= 90 ? '🎉' : '📊',
                  style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              Text(widget.practice ? 'Дайындық аяқталды' : 'Мок тест аяқталды',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: score.scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: score.scoreColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text('${score.totalScore} / 140',
                        style: TextStyle(
                            color: score.scoreColor,
                            fontSize: 34,
                            fontWeight: FontWeight.w900)),
                    Text(score.scoreGrade,
                        style: TextStyle(
                            color: score.scoreColor,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _resRow('Қазақстан тарихы', score.kazakhHistory,
                  ScoreModel.maxKazakhHistory),
              _resRow('Оқу сауаттылығы', score.readingLiteracy,
                  ScoreModel.maxReadingLiteracy),
              _resRow('Матем. сауаттылық', score.mathLiteracy,
                  ScoreModel.maxMathLiteracy),
              _resRow(score.elective1Name ?? 'Таңдау 1', score.elective1,
                  ScoreModel.maxElective),
              _resRow(score.elective2Name ?? 'Таңдау 2', score.elective2,
                  ScoreModel.maxElective),
              if (widget.practice) ...[
                const SizedBox(height: 10),
                Text('Бұл нәтиже рейтингке әсер етпейді',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text('Аяқтау'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resRow(String label, int score, int max) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            Text('$score / $max',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.navyBlue)),
          ],
        ),
      );

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Тест кезінде артқа шығу — растаумен. Аяқталса/қате болса — еркін шығады.
    return PopScope(
      canPop: _completed || _error != null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_title),
          backgroundColor: AppColors.navyBlue,
          automaticallyImplyLeading: false, // тест кезінде артқа қайту жоқ
          actions: [
            if (!_loading && _error == null) ...[
              _timerChip(),
              const SizedBox(width: 12),
            ],
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue))
            : _error != null
                ? _errorState()
                : _quizBody(),
      ),
    );
  }

  Widget _timerChip() {
    final m = _remaining.inMinutes;
    final danger = m < 5; // соңғы 5 минут — қызыл, жыпылықтайды
    final warn = m < 10; // соңғы 10 минут — сары
    final Color bg = danger
        ? AppColors.error
        : (warn ? AppColors.warning : Colors.white.withValues(alpha: 0.15));
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: danger && !_blink ? 0.35 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.white, size: 18),
            const SizedBox(width: 6),
            Text(_fmt(_remaining),
                style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox_outlined,
                  size: 56, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      );

  Widget _quizBody() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subjectBand(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _progressRow(),
                  const SizedBox(height: 10),
                  _statsRow(),
                  const SizedBox(height: 14),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: _questionScroll(key: ValueKey(_index)),
                    ),
                  ),
                  _navigatorStrip(),
                  _bottomBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Пәндік header + пәндер арасында ауысу ──────────────────────────────────
  Widget _subjectBand() {
    final g = _currentGroup;
    final answered = _answeredIn(g);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navyDark, AppColors.navyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(g.icon, color: AppColors.gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${g.indices.length} сұрақ · $answered жауап берілді',
                        style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _groups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _subjectTab(_groups[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectTab(_SubjectGroup g) {
    final active = g.key == _currentGroup.key;
    final answered = _answeredIn(g);
    final done = answered == g.indices.length;
    return GestureDetector(
      onTap: () => _jumpToSubject(g),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(done ? Icons.check_circle_rounded : g.icon,
                size: 16,
                color: active ? AppColors.navyDark : AppColors.white),
            const SizedBox(width: 6),
            Text(g.label,
                style: TextStyle(
                    color: active ? AppColors.navyDark : AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.navyDark.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$answered/${g.indices.length}',
                  style: TextStyle(
                      color: active ? AppColors.navyDark : AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Прогресс ────────────────────────────────────────────────────────────
  Widget _progressRow() {
    final progress = (_index + 1) / _questions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Сұрақ ${_index + 1} ',
                style: const TextStyle(
                    color: AppColors.navyBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            Text('/ ${_questions.length}',
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${(progress * 100).round()}%',
                style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              minHeight: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _statPill(Icons.check_circle_rounded, _answeredCount, AppColors.success,
            'Жауап берілді'),
        const SizedBox(width: 8),
        _statPill(Icons.circle_outlined, _remainingCount, AppColors.textSecondary,
            'Қалды'),
        const SizedBox(width: 8),
        _statPill(Icons.flag_rounded, _flagged.length, AppColors.error, 'Flag'),
      ],
    );
  }

  Widget _statPill(IconData icon, int value, Color color, String tooltip) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text('$value',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Сұрақ + нұсқалар ─────────────────────────────────────────────────────
  Widget _questionScroll({required Key key}) {
    return ListView(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _questionCard(),
        const SizedBox(height: 16),
        ...List.generate(
          _q.options.length,
          (i) => Padding(
            padding: EdgeInsets.only(
                bottom: i == _q.options.length - 1 ? 0 : 10),
            child: _optionTile(i),
          ),
        ),
      ],
    );
  }

  Widget _questionCard() {
    final sectionLabel = _subjectLabel(_q);
    final flagged = _flagged.contains(_index);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDark, AppColors.navyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(sectionLabel.toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0)),
              ),
              const Spacer(),
              // 🚩 Flag — кейін қайта қарау үшін.
              InkWell(
                onTap: _toggleFlag,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: flagged
                        ? AppColors.error
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: flagged
                            ? AppColors.error
                            : Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          flagged
                              ? Icons.flag_rounded
                              : Icons.outlined_flag_rounded,
                          size: 16,
                          color: AppColors.white),
                      const SizedBox(width: 4),
                      Text(flagged ? 'Белгіленді' : 'Flag',
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_q.question.isNotEmpty)
            Text(_q.question,
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.4)),
          if (_q.imageUrl != null) ...[
            const SizedBox(height: 12),
            _QuestionImage(url: _q.imageUrl!),
          ],
          if (_q.isMultiple) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.checklist_rounded,
                    color: AppColors.gold, size: 16),
                const SizedBox(width: 6),
                Text('Бірнеше дұрыс жауап · ${_q.points} балл',
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionTile(int i) {
    final isSelected = _sel.contains(i);
    // Бірден тексеру ЖОҚ — тек таңдалғанын көрсетеміз (дұрыс/қате білінбейді).
    final borderColor = isSelected ? AppColors.navyBlue : AppColors.divider;
    final bgColor =
        isSelected ? AppColors.navyBlue.withValues(alpha: 0.06) : AppColors.white;
    final textColor = isSelected ? AppColors.navyBlue : AppColors.textPrimary;

    return InkWell(
      onTap: () => _toggleOption(i),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
              _q.isMultiple
                  ? (isSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded)
                  : (isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded),
              color: isSelected ? AppColors.navyBlue : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(String.fromCharCode(65 + i),
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_q.options[i],
                  style: TextStyle(
                      color: textColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Сұрақтар картасы (компакт жолақ + толық карта) ─────────────────────────
  Widget _navigatorStrip() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: ListView.separated(
                controller: _stripCtrl,
                scrollDirection: Axis.horizontal,
                itemCount: _currentGroup.indices.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, p) => Center(
                    child: _navDot(_currentGroup.indices[p], size: 42)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Толық сұрақтар картасын ашу.
          Material(
            color: AppColors.navyBlue,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _showNavigatorSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                child: const Icon(Icons.grid_view_rounded,
                    color: AppColors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navDot(int i, {double size = 44, bool inSheet = false}) {
    final answered = _isAnswered(i);
    final flagged = _flagged.contains(i);
    final current = i == _index;
    late Color bg, fg;
    if (flagged) {
      bg = AppColors.error;
      fg = AppColors.white;
    } else if (answered) {
      bg = AppColors.success;
      fg = AppColors.white;
    } else {
      bg = AppColors.white;
      fg = AppColors.textSecondary;
    }
    final borderColor = current
        ? AppColors.info
        : (answered || flagged ? bg : AppColors.border);
    return GestureDetector(
      onTap: () {
        if (inSheet) Navigator.pop(context);
        _goTo(i);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: current ? 3 : 1.5),
          boxShadow: current
              ? [
                  BoxShadow(
                      color: AppColors.info.withValues(alpha: 0.35),
                      blurRadius: 8)
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text('${i + 1}',
                  style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.3)),
            ),
            if (flagged || answered)
              Positioned(
                right: 1,
                top: 1,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: const BoxDecoration(
                      color: AppColors.white, shape: BoxShape.circle),
                  child: Icon(
                      flagged ? Icons.flag_rounded : Icons.check_rounded,
                      size: size * 0.26,
                      color: flagged ? AppColors.error : AppColors.success),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNavigatorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Column(
          children: [
            _sheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.grid_view_rounded, color: AppColors.navyBlue),
                  const SizedBox(width: 8),
                  Text('Сұрақтар картасы',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            _legend(),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  for (final g in _groups) ...[
                    Row(
                      children: [
                        Icon(g.icon, size: 18, color: AppColors.navyBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(g.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.textPrimary)),
                        ),
                        Text('${_answeredIn(g)}/${g.indices.length}',
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final i in g.indices)
                          _navDot(i, size: 46, inSheet: true)
                      ],
                    ),
                    const SizedBox(height: 22),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(Color c, String label, {bool border = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: border ? AppColors.white : c,
                shape: BoxShape.circle,
                border: Border.all(
                    color: border ? AppColors.info : c,
                    width: border ? 3 : 1),
              ),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          item(AppColors.white, 'Жауап жоқ'),
          item(AppColors.success, 'Жауап берілді'),
          item(AppColors.error, 'Белгіленген'),
          item(AppColors.info, 'Қазіргі', border: true),
        ],
      ),
    );
  }

  // ── Тапсыру алдында summary / тексеру ──────────────────────────────────────
  Future<bool?> _showReviewSheet() {
    final unanswered = [
      for (var i = 0; i < _questions.length; i++)
        if (!_isAnswered(i)) i
    ];
    final flagged = _flagged.toList()..sort();

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Column(
          children: [
            _sheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.fact_check_outlined,
                      color: AppColors.navyBlue),
                  const SizedBox(width: 8),
                  Text('Тапсыру алдында тексеру',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  Row(
                    children: [
                      _reviewStat('Жауап берілген',
                          '$_answeredCount', AppColors.success),
                      const SizedBox(width: 10),
                      _reviewStat('Жауап берілмеген',
                          '${unanswered.length}', AppColors.error),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _reviewStat(
                          'Белгіленген', '${flagged.length}', AppColors.gold),
                      const SizedBox(width: 10),
                      _reviewStat(
                          'Уақыт қалды', _fmt(_remaining), AppColors.navyBlue),
                    ],
                  ),
                  if (unanswered.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text('Жауап берілмеген сұрақтар (${unanswered.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.error,
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Сұраққа өту үшін нөмірін басыңыз.',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final i in unanswered)
                          _jumpChip(i, AppColors.error)
                      ],
                    ),
                  ],
                  if (flagged.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text('Белгіленген сұрақтар (${flagged.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.goldDark,
                            fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final i in flagged) _jumpChip(i, AppColors.goldDark)
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Жалғастыру'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyBlue,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Аяқтау'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _jumpChip(int i, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // картаны/sheet жабу (proceed=false)
        _goTo(i);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text('№${i + 1}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }

  Widget _sheetHandle() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 8),
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  // ── Төменгі панель ─────────────────────────────────────────────────────────
  Widget _bottomBar() {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom > 0 ? 4 : 8),
      child: Row(
        children: [
          if (_index > 0) ...[
            OutlinedButton.icon(
              onPressed: () => _go(-1),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Алдыңғы'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navyBlue,
                side: const BorderSide(color: AppColors.navyBlue),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _finishing
                  ? null
                  : (_isLast ? _onFinishPressed : () => _go(1)),
              icon: _finishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2.4))
                  : Icon(
                      _isLast
                          ? Icons.flag_rounded
                          : Icons.arrow_forward_rounded,
                      size: 20),
              label: Text(_isLast ? 'Аяқтау' : 'Келесі',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isLast ? AppColors.success : AppColors.navyBlue,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Сұрақ суреті — заманауи ықшам көрініс (макс. биіктік), басқанда толық экранда
/// үлкейтіп қарауға болады (zoom/pan).
class _QuestionImage extends StatelessWidget {
  final String url;
  const _QuestionImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _ImageViewer(url: url),
      )),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Image.network(
                url,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (c, child, p) => p == null
                    ? child
                    : const SizedBox(
                        height: 140,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.gold, strokeWidth: 2.4))),
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 60,
                  child: Center(
                    child: Text('Суретті жүктеу мүмкін болмады',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.zoom_out_map_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Толық экранды сурет көрсеткіш — үлкейту/жылжыту.
class _ImageViewer extends StatelessWidget {
  final String url;
  const _ImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(child: Image.network(url, fit: BoxFit.contain)),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon:
                  const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
