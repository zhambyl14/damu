// lib/navigation/staff_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/curator/curator_dashboard_screen.dart';
import '../screens/director/director_dashboard_screen.dart';
import '../theme.dart';

class StaffShell extends StatefulWidget {
  final UserRole role;
  const StaffShell({super.key, required this.role});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _currentIndex = 0;

  late final List<Widget> _tabs;
  late final List<BottomNavigationBarItem> _items;

  @override
  void initState() {
    super.initState();

    if (widget.role == UserRole.director ||
        widget.role == UserRole.admin) {
      _tabs = const [
        DirectorDashboardScreen(),
        _StaffProfileTab(),
      ];
      _items = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_rounded),
          label: 'Аналитика',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Профиль',
        ),
      ];
    } else {
      _tabs = const [
        CuratorDashboardScreen(),
        _StaffProfileTab(),
      ];
      _items = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'Сынып',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Профиль',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.navyBlue,
        unselectedItemColor: AppColors.textMuted,
        backgroundColor: AppColors.white,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w700),
        items: _items,
      ),
    );
  }
}

// ── ҚЫЗМЕТКЕРДІҢ ПРОФИЛІ ──────────────────────────────────
class _StaffProfileTab extends StatelessWidget {
  const _StaffProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: AppColors.navyBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.gold, width: 2.5),
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.navyBlue,
                      child: Text(
                        user.initials,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user.name,
                      style:
                          Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(user.roleLabel,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _infoTile(context, Icons.email_rounded, 'Email', user.email),
            if (user.className != null)
              _infoTile(
                  context, Icons.class_rounded, 'Сынып', user.className!),
            _infoTile(
                context, Icons.badge_rounded, 'Рөл', user.roleLabel),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Шығу'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(
      BuildContext context, IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.navyBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodyMedium)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Шығуды растау'),
        content: const Text('Сіз шынымен жүйеден шыққыңыз келе ме?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Болдырмау'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Шығу'),
          ),
        ],
      ),
    );
  }
}