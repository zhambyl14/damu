// lib/screens/admin/add_edit_mock_question_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../data/subjects_catalog.dart';
import '../../models/mock_test_model.dart';
import '../../services/mock_test_service.dart';
import '../../services/question_bank_service.dart';

/// Сұрақ қосады/түзетеді. Екі режим:
///   • мок тест сұрағы (mockId берілген) — mock_questions кестесіне.
///   • сұрақтар банкі (bank: true) — question_bank кестесіне (админ базаны толтырады).
/// Бөлім (section) таңдалады; elective болса — қай бейіндік пән екені көрсетіледі.
class AddEditMockQuestionScreen extends StatefulWidget {
  final String? mockId;
  final MockQuestion? existing;
  final bool bank;

  const AddEditMockQuestionScreen({
    super.key,
    this.mockId,
    this.existing,
    this.bank = false,
  });

  @override
  State<AddEditMockQuestionScreen> createState() =>
      _AddEditMockQuestionScreenState();
}

class _AddEditMockQuestionScreenState extends State<AddEditMockQuestionScreen> {
  final _service = MockTestService();
  final _bank = QuestionBankService();
  final _formKey = GlobalKey<FormState>();
  final _questionCtrl = TextEditingController();
  final _explanationCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  List<TextEditingController> _options = [];
  final Set<int> _correct = {0}; // дұрыс жауап индекстері
  bool _multi = false; // бірнеше дұрыс жауап
  int _points = 1;

  String _section = MockSection.kazakhHistory;
  String? _electiveSubjectId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _questionCtrl.text = ex.question;
      _explanationCtrl.text = ex.explanation ?? '';
      _imageCtrl.text = ex.imageUrl ?? '';
      _options = ex.options.map((o) => TextEditingController(text: o)).toList();
      _correct
        ..clear()
        ..addAll(ex.correctIndices.where((i) => i >= 0 && i < ex.options.length));
      if (_correct.isEmpty) _correct.add(0);
      _multi = ex.isMultiple;
      _points = ex.points;
      _section = ex.section;
      _electiveSubjectId = ex.subjectId;
    }
    if (_options.length < 2) {
      _options = List.generate(4, (_) => TextEditingController());
    }
    _electiveSubjectId ??= SubjectCatalog.electives.first.id;
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _explanationCtrl.dispose();
    _imageCtrl.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final options =
        _options.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (options.length < 2) {
      _snack('Кемінде 2 жауап нұсқасын толтырыңыз');
      return;
    }
    final correct = _correct.where((i) => i < options.length).toList()..sort();
    if (correct.isEmpty) {
      _snack('Кемінде бір дұрыс жауапты белгілеңіз');
      return;
    }

    setState(() => _saving = true);
    final q = MockQuestion(
      id: widget.existing?.id ?? '',
      mockId: widget.mockId ?? '',
      section: _section,
      subjectId: _section == MockSection.elective ? _electiveSubjectId : null,
      question: _questionCtrl.text.trim(),
      options: options,
      correctIndices: correct,
      points: _points,
      imageUrl: _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
      explanation: _explanationCtrl.text.trim().isEmpty
          ? null
          : _explanationCtrl.text.trim(),
      order: widget.existing?.order ?? 0, // жаңа сұраққа order сервисте беріледі
    );

    try {
      if (widget.bank) {
        if (_isEdit) {
          await _bank.updateQuestion(q);
        } else {
          await _bank.addQuestion(q);
        }
      } else {
        if (_isEdit) {
          await _service.updateQuestion(q);
        } else {
          await _service.addQuestion(q);
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack('Қате: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Сұрақты түзету' : 'Жаңа сұрақ'),
        backgroundColor: AppColors.navyBlue,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Бөлім',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.navyBlue, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ...MockSection.mandatory.map((s) => _sectionChip(s)),
                _sectionChip(MockSection.elective),
              ],
            ),
            if (_section == MockSection.elective) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _electiveSubjectId,
                    items: SubjectCatalog.electives
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.title,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _electiveSubjectId = v),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextFormField(
              controller: _questionCtrl,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Сұрақ мәтіні',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Сұрақ мәтінін енгізіңіз'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _imageCtrl,
              decoration: const InputDecoration(
                labelText: 'Сурет URL (міндетті емес)',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.image_outlined,
                    color: AppColors.navyBlue, size: 20),
              ),
            ),
            const SizedBox(height: 18),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _multi,
              activeColor: AppColors.navyBlue,
              title: const Text('Бірнеше дұрыс жауап',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Күрделі сұрақ (26–40), әдетте 2 балл',
                  style: TextStyle(fontSize: 12)),
              onChanged: (v) => setState(() {
                _multi = v;
                if (!v && _correct.length > 1) {
                  final first = _correct.first;
                  _correct
                    ..clear()
                    ..add(first);
                }
                _points = v ? 2 : 1; // ыңғайлы әдепкі балл
              }),
            ),
            Row(
              children: [
                Text('Жауап нұсқалары',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(_multi ? 'Дұрыстарын белгілеңіз' : 'Дұрысын белгілеңіз',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_options.length, (i) => _optionRow(i)),
            if (_options.length < 6)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _options.add(TextEditingController())),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Нұсқа қосу'),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Балл',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                _pointsChip(1),
                const SizedBox(width: 8),
                _pointsChip(2),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _explanationCtrl,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Түсіндірме (міндетті емес)',
                alignLabelWithHint: true,
              ),
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
                            color: AppColors.white, strokeWidth: 2.4))
                    : const Icon(Icons.save_rounded),
                label: Text(_isEdit ? 'Сақтау' : 'Сұрақты қосу'),
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

  Widget _sectionChip(String s) {
    final selected = _section == s;
    return ChoiceChip(
      label: Text(MockSection.label(s)),
      selected: selected,
      onSelected: (_) => setState(() => _section = s),
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
  }

  Widget _pointsChip(int value) {
    final selected = _points == value;
    return ChoiceChip(
      label: Text('$value балл'),
      selected: selected,
      onSelected: (_) => setState(() => _points = value),
      selectedColor: AppColors.gold,
      labelStyle: TextStyle(
        color: selected ? AppColors.navyDark : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
    );
  }

  void _toggleCorrect(int i) {
    setState(() {
      if (_multi) {
        _correct.contains(i) ? _correct.remove(i) : _correct.add(i);
        if (_correct.isEmpty) _correct.add(i); // кемінде біреу қалсын
      } else {
        _correct
          ..clear()
          ..add(i);
      }
    });
  }

  Widget _optionRow(int i) {
    final isCorrect = _correct.contains(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isCorrect ? AppColors.success.withValues(alpha: 0.06) : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? AppColors.success : AppColors.divider,
          width: isCorrect ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _multi
                  ? (isCorrect
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded)
                  : (isCorrect
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded),
              color: isCorrect ? AppColors.success : AppColors.textMuted,
            ),
            onPressed: () => _toggleCorrect(i),
          ),
          Text(String.fromCharCode(65 + i),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isCorrect ? AppColors.success : AppColors.navyBlue)),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _options[i],
              decoration: const InputDecoration(
                hintText: 'Жауап нұсқасы',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_options.length > 2)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textMuted),
              onPressed: () => setState(() {
                _options[i].dispose();
                _options.removeAt(i);
                // индекстерді қайта реттеу: жойылғаннан кейінгілер 1-ге жылжиды
                final updated = <int>{};
                for (final c in _correct) {
                  if (c < i) {
                    updated.add(c);
                  } else if (c > i) {
                    updated.add(c - 1);
                  }
                }
                _correct
                  ..clear()
                  ..addAll(updated);
                if (_correct.isEmpty) _correct.add(0);
              }),
            ),
        ],
      ),
    );
  }
}
