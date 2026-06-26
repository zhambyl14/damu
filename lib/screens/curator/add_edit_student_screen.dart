// lib/screens/curator/add_edit_student_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../services/user_admin_service.dart';

/// Куратор жаңа оқушы тіркейді немесе бар оқушының профилін түзетеді.
class AddEditStudentScreen extends StatefulWidget {
  final UserModel curator;
  final UserModel? existing;

  const AddEditStudentScreen({
    super.key,
    required this.curator,
    this.existing,
  });

  @override
  State<AddEditStudentScreen> createState() => _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends State<AddEditStudentScreen> {
  final _admin = UserAdminService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();

  ElectiveProfile _profile = ElectiveProfile.unknown;
  StudentType _studentType = StudentType.online;
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
      _profile = ex.electiveProfile;
      _studentType = ex.studentType;
    } else {
      // Жаңа оқушы — куратордың сыныбын алдын ала қою
      _classCtrl.text = widget.curator.className ?? '';
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
    if (_profile == ElectiveProfile.unknown) {
      setState(() => _error = 'Таңдау профилін көрсетіңіз');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final grade = int.tryParse(_gradeCtrl.text.trim());
    final className =
        _classCtrl.text.trim().isEmpty ? null : _classCtrl.text.trim();

    try {
      if (_isEdit) {
        await _admin.updateStudent(
          uid: widget.existing!.uid,
          name: _nameCtrl.text,
          className: className,
          grade: grade,
          electivePairKey: UserModel.electiveKey(_profile),
          studentType: _studentType.name,
        );
      } else {
        await _admin.createStudent(
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passCtrl.text,
          curatorId: widget.curator.uid,
          electivePairKey: UserModel.electiveKey(_profile),
          studentType: _studentType.name,
          className: className,
          classId: widget.curator.classId,
          grade: grade,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Оқушы жаңартылды' : 'Оқушы тіркелді'),
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
        title: Text(_isEdit ? 'Оқушыны түзету' : 'Жаңа оқушы'),
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
                hintText: 'student@mektep.kz',
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
                  helperText: 'Оқушыға беріңіз — кейін өзгерте алады',
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
            const SizedBox(height: 16),
            Text('Оқушы типі',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.navyBlue, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: StudentType.values.map((t) {
                final selected = _studentType == t;
                final isOnline = t == StudentType.online;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isOnline ? 10 : 0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _studentType = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.navyBlue.withValues(alpha: 0.06)
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.navyBlue
                                : AppColors.divider,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              isOnline
                                  ? Icons.wifi_rounded
                                  : Icons.wifi_off_rounded,
                              color: selected
                                  ? AppColors.navyBlue
                                  : AppColors.textMuted,
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(isOnline ? 'Онлайн' : 'Оффлайн',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? AppColors.navyBlue
                                      : AppColors.textPrimary,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              _studentType == StudentType.online
                  ? 'Барлық мүмкіндіктерге доступ (видеосабақ + тақырыптық тест)'
                  : 'Видеосабақ пен оның тақырыптық тестінен басқасына доступ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('Таңдау профилі',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.navyBlue, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ElectiveProfile>(
                  isExpanded: true,
                  value: _profile == ElectiveProfile.unknown ? null : _profile,
                  hint: const Text('Профильді таңдаңыз'),
                  items: UserModel.selectableProfiles
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(UserModel.electiveLabel(p),
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(
                      () => _profile = v ?? ElectiveProfile.unknown),
                ),
              ),
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
                label: Text(_isEdit ? 'Сақтау' : 'Оқушыны тіркеу'),
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
