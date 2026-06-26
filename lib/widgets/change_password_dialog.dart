// lib/widgets/change_password_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/auth_provider.dart';

/// Құпия сөзді өзгерту парағын ашады (профильден қолданылады).
Future<void> showChangePasswordSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChangePasswordSheet(),
  );
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context
          .read<AuthProvider>()
          .changePassword(_currentCtrl.text, _newCtrl.text);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Құпия сөз сәтті өзгертілді'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Құпия сөзді өзгерту',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              TextFormField(
                controller: _currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Ағымдағы құпия сөз',
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: AppColors.navyBlue, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Ағымдағы құпия сөзді енгізіңіз' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Жаңа құпия сөз',
                  prefixIcon: Icon(Icons.lock_reset_rounded,
                      color: AppColors.navyBlue, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Жаңа құпия сөзді енгізіңіз';
                  if (v.length < 6) return 'Кемінде 6 таңба';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Жаңа құпия сөзді қайталаңыз',
                  prefixIcon: Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.navyBlue, size: 20),
                ),
                validator: (v) =>
                    v != _newCtrl.text ? 'Құпия сөздер сәйкес келмейді' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.w500)),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    foregroundColor: AppColors.white,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2.4),
                        )
                      : const Text('Сақтау'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
