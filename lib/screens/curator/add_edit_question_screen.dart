// lib/screens/curator/add_edit_question_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/question_model.dart';
import '../../services/content_service.dart';

/// Куратор тест сұрағын қосады/түзетеді (2–6 жауап нұсқасы).
class AddEditQuestionScreen extends StatefulWidget {
  final String subjectId;
  final String topicId;
  final String curatorUid;
  final QuestionModel? existing;

  const AddEditQuestionScreen({
    super.key,
    required this.subjectId,
    required this.topicId,
    required this.curatorUid,
    this.existing,
  });

  @override
  State<AddEditQuestionScreen> createState() => _AddEditQuestionScreenState();
}

class _AddEditQuestionScreenState extends State<AddEditQuestionScreen> {
  final _content = ContentService();
  final _formKey = GlobalKey<FormState>();
  final _questionCtrl = TextEditingController();
  final _explanationCtrl = TextEditingController();

  List<TextEditingController> _options = [];
  int _correctIndex = 0;
  int _points = 1;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _questionCtrl.text = ex.question;
      _explanationCtrl.text = ex.explanation ?? '';
      _options =
          ex.options.map((o) => TextEditingController(text: o)).toList();
      _correctIndex = ex.correctIndex.clamp(0, ex.options.length - 1);
      _points = ex.points;
    }
    if (_options.length < 2) {
      _options = [
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ];
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _explanationCtrl.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= 6) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int i) {
    if (_options.length <= 2) return;
    setState(() {
      _options[i].dispose();
      _options.removeAt(i);
      if (_correctIndex >= _options.length) {
        _correctIndex = _options.length - 1;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final options =
        _options.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (options.length < 2) {
      _snack('Кемінде 2 жауап нұсқасын толтырыңыз', isError: true);
      return;
    }
    if (_correctIndex >= options.length) _correctIndex = 0;

    setState(() => _saving = true);
    final q = QuestionModel(
      id: widget.existing?.id ?? '',
      subjectId: widget.subjectId,
      topicId: widget.topicId,
      question: _questionCtrl.text.trim(),
      options: options,
      correctIndex: _correctIndex,
      explanation: _explanationCtrl.text.trim().isEmpty
          ? null
          : _explanationCtrl.text.trim(),
      points: _points,
      order: widget.existing?.order ?? 0, // жаңа сұраққа order сервисте беріледі
      createdBy: widget.existing?.createdBy ?? widget.curatorUid,
      createdAt: widget.existing?.createdAt,
    );

    try {
      if (_isEdit) {
        await _content.updateQuestion(q);
      } else {
        await _content.addQuestion(q);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      _snack(_isEdit ? 'Сұрақ жаңартылды' : 'Сұрақ қосылды');
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
        title: Text(_isEdit ? 'Сұрақты түзету' : 'Жаңа сұрақ'),
        backgroundColor: AppColors.navyBlue,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _questionCtrl,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Сұрақ мәтіні',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.help_outline_rounded,
                    color: AppColors.navyBlue, size: 20),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Сұрақ мәтінін енгізіңіз' : null,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text('Жауап нұсқалары',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Дұрысын белгілеңіз',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_options.length, (i) => _optionRow(i)),
            if (_options.length < 6)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Нұсқа қосу'),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _explanationCtrl,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Түсіндірме (міндетті емес)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.lightbulb_outline_rounded,
                    color: AppColors.navyBlue, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Ұпай:',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 12),
                ...[1, 2, 3].map((p) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$p'),
                        selected: _points == p,
                        onSelected: (_) => setState(() => _points = p),
                        selectedColor: AppColors.navyBlue,
                        labelStyle: TextStyle(
                          color: _points == p
                              ? AppColors.white
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )),
              ],
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

  Widget _optionRow(int i) {
    final isCorrect = _correctIndex == i;
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
          Radio<int>(
            value: i,
            groupValue: _correctIndex,
            activeColor: AppColors.success,
            onChanged: (v) => setState(() => _correctIndex = v ?? 0),
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
              onPressed: () => _removeOption(i),
            ),
        ],
      ),
    );
  }
}
