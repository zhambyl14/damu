// lib/screens/admin/admin_management_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import 'manage_curators_screen.dart';
import 'manage_students_admin_screen.dart';
import 'manage_directors_screen.dart';

/// Әкімнің басқару хабы: кураторлар, оқушылар, директорлар.
class AdminManagementScreen extends StatelessWidget {
  const AdminManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Басқару'),
        backgroundColor: AppColors.navyBlue,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card(
            context,
            icon: Icons.supervisor_account_rounded,
            color: AppColors.navyBlue,
            title: 'Кураторлар',
            subtitle: 'Тіркеу, түзету, өшіру (оқушыларды көшіру)',
            screen: const ManageCuratorsScreen(),
          ),
          const SizedBox(height: 12),
          _card(
            context,
            icon: Icons.groups_rounded,
            color: AppColors.gold,
            title: 'Оқушылар',
            subtitle: 'Барлық тіркелген оқушыларды қарау/басқару',
            screen: const ManageStudentsAdminScreen(),
          ),
          const SizedBox(height: 12),
          _card(
            context,
            icon: Icons.workspace_premium_rounded,
            color: AppColors.success,
            title: 'Директорлар',
            subtitle: 'Директор аккаунтын жасау/басқару',
            screen: const ManageDirectorsScreen(),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
