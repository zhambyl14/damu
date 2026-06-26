// lib/navigation/curator_shell.dart
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/staff_profile_tab.dart';
import '../screens/curator/curator_dashboard_screen.dart';
import '../screens/curator/manage_students_screen.dart';
import '../screens/curator/curator_mock_tests_screen.dart';

/// Куратордың негізгі қабығы.
/// Контент (база) — әкімшінің жұмысы, сондықтан кураторда жоқ.
/// Кураторда: Сынып (анализ + балл), Оқушылар, Профиль.
class CuratorShell extends StatefulWidget {
  const CuratorShell({super.key});

  @override
  State<CuratorShell> createState() => _CuratorShellState();
}

class _CuratorShellState extends State<CuratorShell> {
  int _index = 0;

  static const _tabs = [
    CuratorDashboardScreen(),
    ManageStudentsScreen(),
    CuratorMockTestsScreen(),
    StaffProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.navyBlue,
        unselectedItemColor: AppColors.textMuted,
        backgroundColor: AppColors.white,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'Сынып'),
          BottomNavigationBarItem(
              icon: Icon(Icons.groups_rounded), label: 'Оқушылар'),
          BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_rounded), label: 'Мок тест'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Профиль'),
        ],
      ),
    );
  }
}
