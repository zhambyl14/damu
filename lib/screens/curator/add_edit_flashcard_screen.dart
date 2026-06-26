// lib/screens/curator/add_edit_flashcard_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/flashcard_model.dart';
import '../../services/content_service.dart';

/// Куратор флешкарта қосады/түзетеді.
class AddEditFlashcardScreen extends StatefulWidget {
  final String subjectId;
  final String topicId;
  final String curatorUid;
  final FlashcardModel? existing;

  const AddEditFlashcardScreen({
    super.key,
    required this.subjectId,
    required this.topicId,
    required this.curatorUid,
    this.existing,
  });

  @override
  State<AddEditFlashcardScreen> createState() => _AddEditFlashcardScreenState();
}

class _AddEditFlashcardScreenState extends State<AddEditFlashcardScreen> {
  final _content = ContentService();
  final _formKey = GlobalKey<FormState>();
  final _frontCtrl = TextEditingController();
  final _backCtrl = TextEditingController();
  final _hintCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _frontCtrl.text = ex.front;
      _backCtrl.text = ex.back;
      _hintCtrl.text = ex.hint ?? '';
    }
  }

  @override
  void dispose() {
    _frontCtrl.dispose();
    _backCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final f = FlashcardModel(
      id: widget.existing?.id ?? '',
      subjectId: widget.subjectId,
      topicId: widget.topicId,
      front: _frontCtrl.text.trim(),
      back: _backCtrl.text.trim(),
      hint: _hintCtrl.text.trim().isEmpty ? null : _hintCtrl.text.trim(),
      order: widget.existing?.order ?? 0, // жаңа карточкаға order сервисте беріледі
      createdBy: widget.existing?.createdBy ?? widget.curatorUid,
      createdAt: widget.existing?.createdAt,
    );

    try {
      if (_isEdit) {
        await _content.updateFlashcard(f);
      } else {
        await _content.addFlashcard(f);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Флешкарта жаңартылды' : 'Флешкарта қосылды'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Қате: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Флешкартаны түзету' : 'Жаңа флешкарта'),
        backgroundColor: AppColors.navyBlue,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _label('Алды (сұрақ / термин)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _frontCtrl,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Мысалы: Қазақ хандығы қашан құрылды?',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Алдыңғы жағын толтырыңыз' : null,
            ),
            const SizedBox(height: 16),
            _label('Арты (жауап / анықтама)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _backCtrl,
              maxLines: 5,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: 'Мысалы: 1465 жылы Керей мен Жәнібек құрды',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Артқы жағын толтырыңыз' : null,
            ),
            const SizedBox(height: 16),
            _label('Кеңес (міндетті емес)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _hintCtrl,
              decoration: const InputDecoration(
                hintText: 'Мысалы: XV ғасырдың ортасы',
                prefixIcon: Icon(Icons.lightbulb_outline_rounded,
                    color: AppColors.gold, size: 20),
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
                            color: AppColors.white, strokeWidth: 2.4),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isEdit ? 'Сақтау' : 'Флешкарта қосу'),
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

  Widget _label(String text) => Text(text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.navyBlue, fontWeight: FontWeight.w700));
}
