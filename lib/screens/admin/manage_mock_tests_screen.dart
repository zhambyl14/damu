// lib/screens/admin/manage_mock_tests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../models/mock_test_model.dart';
import '../../services/mock_test_service.dart';
import '../../providers/auth_provider.dart';
import 'mock_questions_screen.dart';

/// Әкімші мектеп мок тесттерін жасайды/басқарады.
class ManageMockTestsScreen extends StatelessWidget {
  const ManageMockTestsScreen({super.key});

  MockTestService get _service => MockTestService();

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AuthProvider>().userModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Мок тесттер'),
        backgroundColor: AppColors.navyBlue,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDark,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Мок тест'),
        onPressed: () => _editDialog(context, admin?.uid),
      ),
      body: StreamBuilder<List<MockTest>>(
        stream: _service.watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }
          final mocks = snap.data ?? [];
          if (mocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fact_check_outlined,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('Мок тесттер жоқ',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Text('"Мок тест" батырмасымен жасаңыз',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: mocks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _card(context, mocks[i]),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, MockTest m) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MockQuestionsScreen(mock: m)),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: (m.active ? AppColors.success : AppColors.textMuted)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fact_check_rounded,
                    color: m.active ? AppColors.success : AppColors.textMuted,
                    size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (m.active
                                    ? AppColors.success
                                    : AppColors.textMuted)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(m.active ? 'Белсенді' : 'Жасырын',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: m.active
                                      ? AppColors.success
                                      : AppColors.textMuted)),
                        ),
                        const SizedBox(width: 8),
                        Text('Сұрақтарды басқару →',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted),
                onSelected: (v) {
                  if (v == 'edit') {
                    _editDialog(context, m.createdBy, existing: m);
                  } else if (v == 'toggle') {
                    _service.updateMock(m.id, {'active': !m.active});
                  } else {
                    _confirmDelete(context, m);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded,
                          size: 18, color: AppColors.navyBlue),
                      SizedBox(width: 10),
                      Text('Түзету'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(
                          m.active
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 18,
                          color: AppColors.navyBlue),
                      const SizedBox(width: 10),
                      Text(m.active ? 'Жасыру' : 'Белсендіру'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Өшіру'),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editDialog(BuildContext context, String? adminUid,
      {MockTest? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl =
        TextEditingController(text: existing?.description ?? '');
    bool active = existing?.active ?? true;
    final isEdit = existing != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? 'Мок тестті түзету' : 'Жаңа мок тест'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Атауы',
                  hintText: 'Мысалы: Қазан айы мок тесті',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Сипаттама (міндетті емес)',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Белсенді (оқушыларға көрінеді)'),
                value: active,
                activeThumbColor: AppColors.navyBlue,
                onChanged: (v) => setLocal(() => active = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Болдырмау')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сақтау'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final desc = descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();

    if (isEdit) {
      await _service.updateMock(existing.id, {
        'title': title,
        'description': desc,
        'active': active,
      });
    } else {
      await _service.addMock(MockTest(
        id: '',
        title: title,
        description: desc,
        active: active,
        createdBy: adminUid,
      ));
    }
  }

  Future<void> _confirmDelete(BuildContext context, MockTest m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Мок тестті өшіру'),
        content: Text(
            '"${m.title}" және оның барлық сұрақтары өшеді. Жалғастырамыз ба?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Болдырмау')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Өшіру'),
          ),
        ],
      ),
    );
    if (ok == true) await _service.deleteMock(m.id);
  }
}
