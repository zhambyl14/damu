// lib/screens/curator/add_edit_score_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../models/score_model.dart';
import '../../services/score_service.dart';
import '../../services/notification_service.dart';

/// Куратор оқушыға ҰБТ сынақ нәтижесін (балл) енгізеді/түзетеді.
class AddEditScoreScreen extends StatefulWidget {
  final UserModel curator;

  /// Алдын ала таңдалған оқушы (StudentScoresScreen-нен ашқанда).
  final UserModel? student;

  /// Түзету режимі (бар жазба).
  final ScoreModel? existing;

  const AddEditScoreScreen({
    super.key,
    required this.curator,
    this.student,
    this.existing,
  });

  @override
  State<AddEditScoreScreen> createState() => _AddEditScoreScreenState();
}

class _AddEditScoreScreenState extends State<AddEditScoreScreen> {
  final _scoreService = ScoreService();
  final _notifications = NotificationService();
  final _formKey = GlobalKey<FormState>();
  final _testNameCtrl = TextEditingController();

  List<UserModel> _students = [];
  bool _loadingStudents = false;
  UserModel? _selected;

  String _testType = 'monthly';
  DateTime _date = DateTime.now();

  int _kazakhHistory = 0;
  int _readingLiteracy = 0;
  int _mathLiteracy = 0;
  int _elective1 = 0;
  int _elective2 = 0;

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _selected = widget.student;

    final ex = widget.existing;
    if (ex != null) {
      _testType = ex.testType;
      _testNameCtrl.text = ex.testName ?? '';
      _date = ex.date;
      _kazakhHistory = ex.kazakhHistory;
      _readingLiteracy = ex.readingLiteracy;
      _mathLiteracy = ex.mathLiteracy;
      _elective1 = ex.elective1;
      _elective2 = ex.elective2;
    }

    if (_selected == null) _loadStudents();
  }

  @override
  void dispose() {
    _testNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _loadingStudents = true);
    final supabase = Supabase.instance.client;
    final res = await supabase
        .from('users')
        .select()
        .eq('curator_id', widget.curator.uid)
        .eq('role', 'student')
        .order('name', ascending: true);
    if (!mounted) return;
    setState(() {
      _students = (res as List)
          .map((d) => UserModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
          .toList();
      _loadingStudents = false;
    });
  }

  List<ElectiveSubject> get _electiveSubjects =>
      _selected?.electiveSubjects ?? const [];

  String get _elective1Label => _electiveSubjects.isNotEmpty
      ? _electiveSubjects[0].label
      : 'Таңдау пәні 1';
  String get _elective2Label => _electiveSubjects.length > 1
      ? _electiveSubjects[1].label
      : 'Таңдау пәні 2';

  int get _total =>
      _kazakhHistory + _readingLiteracy + _mathLiteracy + _elective1 + _elective2;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_selected == null) {
      _snack('Оқушыны таңдаңыз', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final student = _selected!;
    final score = ScoreModel(
      id: widget.existing?.id ?? '',
      studentId: student.uid,
      studentName: student.name,
      className: student.className,
      curatorId: widget.curator.uid,
      date: _date,
      testType: _testType,
      testName: _testNameCtrl.text.trim().isEmpty
          ? null
          : _testNameCtrl.text.trim(),
      kazakhHistory: _kazakhHistory,
      readingLiteracy: _readingLiteracy,
      mathLiteracy: _mathLiteracy,
      elective1: _elective1,
      elective2: _elective2,
      elective1Name: _elective1Label,
      elective2Name: _elective2Label,
    );

    try {
      if (_isEdit) {
        await _scoreService.updateScoreModel(score);
      } else {
        await _scoreService.addScore(score);
        await _notifications.send(
          userId: student.uid,
          title: 'Жаңа тест нәтижесі',
          body:
              '${score.testName ?? "ҰБТ сынағы"} — ${score.totalScore}/140 балл',
          type: 'score',
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      _snack(_isEdit ? 'Нәтиже жаңартылды' : 'Тест нәтижесі қосылды');
    } catch (e) {
      if (mounted) _snack('Қате: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Нәтижені түзету' : 'Тест нәтижесін қосу'),
        backgroundColor: AppColors.navyBlue,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Оқушы ──
            Text('Оқушы',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.navyBlue, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _studentField(),

            const SizedBox(height: 20),
            // ── Тест туралы ──
            Text('Тест туралы',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.navyBlue, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _testNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Тест атауы',
                hintText: 'Мысалы: Қаңтар сынағы',
                prefixIcon: Icon(Icons.title_rounded,
                    color: AppColors.navyBlue, size: 20),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Атауын енгізіңіз' : null,
            ),
            const SizedBox(height: 12),
            _typeSelector(),
            const SizedBox(height: 12),
            _dateTile(),

            const SizedBox(height: 20),
            // ── Баллдар ──
            Row(
              children: [
                Text('Баллдар',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Жалпы: $_total / 140',
                      style: const TextStyle(
                          color: AppColors.navyBlue,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ScoreSlider(
              label: 'Қазақстан тарихы',
              value: _kazakhHistory,
              max: 20,
              color: const Color(0xFFC0392B),
              onChanged: (v) => setState(() => _kazakhHistory = v),
            ),
            _ScoreSlider(
              label: 'Оқу сауаттылығы',
              value: _readingLiteracy,
              max: ScoreModel.maxReadingLiteracy,
              color: const Color(0xFF8E44AD),
              onChanged: (v) => setState(() => _readingLiteracy = v),
            ),
            _ScoreSlider(
              label: 'Математикалық сауаттылық',
              value: _mathLiteracy,
              max: ScoreModel.maxMathLiteracy,
              color: const Color(0xFF27AE60),
              onChanged: (v) => setState(() => _mathLiteracy = v),
            ),
            _ScoreSlider(
              label: _elective1Label,
              value: _elective1,
              max: ScoreModel.maxElective,
              color: const Color(0xFF2980B9),
              onChanged: (v) => setState(() => _elective1 = v),
            ),
            _ScoreSlider(
              label: _elective2Label,
              value: _elective2,
              max: ScoreModel.maxElective,
              color: const Color(0xFF16A085),
              onChanged: (v) => setState(() => _elective2 = v),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: AppColors.white, strokeWidth: 2.4),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isEdit ? 'Сақтау' : 'Нәтижені қосу'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  foregroundColor: AppColors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _studentField() {
    // Түзету режимінде немесе алдын ала таңдалғанда — өзгермейді
    if (widget.student != null) {
      final s = widget.student!;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.navyBlue.withValues(alpha: 0.08),
              child: Text(s.initials,
                  style: const TextStyle(
                      color: AppColors.navyBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(s.electiveProfileLabel,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_loadingStudents) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.navyBlue)),
      );
    }

    if (_students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'Оқушылар тіркелмеген. Алдымен "Оқушылар" бөлімінен оқушы қосыңыз.',
          style: TextStyle(color: AppColors.warning),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserModel>(
          isExpanded: true,
          value: _selected,
          hint: const Text('Оқушыны таңдаңыз'),
          items: _students
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name,
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selected = v),
        ),
      ),
    );
  }

  Widget _typeSelector() {
    const types = {
      'monthly': 'Айлық сынақ',
      'internal_mock': 'Ішкі сынақ',
      'state_exam': 'Ресми ҰБТ',
    };
    return Wrap(
      spacing: 8,
      children: types.entries.map((e) {
        final selected = _testType == e.key;
        return ChoiceChip(
          label: Text(e.value),
          selected: selected,
          onSelected: (_) => setState(() => _testType = e.key),
          selectedColor: AppColors.navyBlue,
          labelStyle: TextStyle(
            color: selected ? AppColors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.divider),
          ),
        );
      }).toList(),
    );
  }

  Widget _dateTile() {
    const months = [
      'Қаңтар', 'Ақпан', 'Наурыз', 'Сәуір', 'Мамыр', 'Маусым',
      'Шілде', 'Тамыз', 'Қыркүйек', 'Қазан', 'Қараша', 'Желтоқсан'
    ];
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: AppColors.navyBlue, size: 18),
            const SizedBox(width: 12),
            Text('${_date.day} ${months[_date.month - 1]} ${_date.year}',
                style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            const Icon(Icons.edit_calendar_rounded,
                color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Балл слайдері ───────────────────────────────────────────
class _ScoreSlider extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  final ValueChanged<int> onChanged;

  const _ScoreSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                color: color,
              ),
              SizedBox(
                width: 54,
                child: Text(
                  '$value / $max',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: value < max ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                color: color,
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              inactiveTrackColor: color.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.toDouble().clamp(0, max.toDouble()),
              min: 0,
              max: max.toDouble(),
              divisions: max,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}
