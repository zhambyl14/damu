// lib/screens/admin/add_edit_curator_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../services/user_admin_service.dart';

/// Жаңа куратор тіркеу немесе бар куратор профилін түзету.
class AddEditCuratorScreen extends StatefulWidget {
  final UserModel? existing;

  const AddEditCuratorScreen({super.key, this.existing});

  @override
  State<AddEditCuratorScreen> createState() => _AddEditCuratorScreenState();
}

class _AddEditCuratorScreenState extends State<AddEditCuratorScreen> {
  final _admin = UserAdminService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _nameCtrl.text = ex.name;
      _emailCtrl.text = ex.email;
      _classCtrl.text = ex.className ?? '';
      _gradeCtrl.text = ex.grade?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _classCtrl.dispose();
    _gradeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final grade = int.tryParse(_gradeCtrl.text.trim());
    final className =
        _classCtrl.text.trim().isEmpty ? null : _classCtrl.text.trim();

    try {
      if (_isEdit) {
        await _admin.updateCurator(
          uid: widget.existing!.uid,
          name: _nameCtrl.text,
          className: className,
          grade: grade,
        );
      } else {
        await _admin.createCurator(
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passCtrl.text,
          className: className,
          grade: grade,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Куратор жаңартылды' : 'Куратор тіркелді'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } catch (e) {
      setState(() => _error = 'Қате: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Кураторды түзету' : 'Жаңа куратор'),
        backgroundColor: AppColors.navyBlue,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Аты-жөні',
                prefixIcon: Icon(Icons.person_outline_rounded,
                    color: AppColors.navyBlue, size: 20),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Атын енгізіңіз' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              enabled: !_isEdit,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'curator@mektep.kz',
                prefixIcon: const Icon(Icons.email_outlined,
                    color: AppColors.navyBlue, size: 20),
                helperText: _isEdit ? 'Email өзгертілмейді' : null,
              ),
              validator: (v) {
                if (_isEdit) return null;
                if (v == null || v.trim().isEmpty) return 'Email енгізіңіз';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Жарамды email енгізіңіз';
                }
                return null;
              },
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Бастапқы құпия сөз',
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: AppColors.navyBlue, size: 20),
                  helperText: 'Кураторға беріңіз — кейін өзгерте алады',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Құпия сөз енгізіңіз';
                  if (v.length < 6) return 'Кемінде 6 таңба';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _classCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Сынып',
                      hintText: '11А',
                      prefixIcon: Icon(Icons.class_outlined,
                          color: AppColors.navyBlue, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _gradeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Жыл',
                      hintText: '11',
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ],
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
                label: Text(_isEdit ? 'Сақтау' : 'Куратор тіркеу'),
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
}
