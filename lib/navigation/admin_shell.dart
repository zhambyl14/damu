// lib/navigation/admin_shell.dart
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/staff_profile_tab.dart';
import '../screens/curator/manage_content_screen.dart';
import '../screens/admin/question_bank_screen.dart';
import '../screens/admin/admin_management_screen.dart';
import '../screens/director/director_dashboard_screen.dart';

/// Әкімші (программист) қабығы: база/контент жұмысы осында.
/// Контент (пән→тақырып→видео/сұрақ/флешкарта), Мок тесттер, Аналитика, Профиль.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _tabs = [
    ManageContentScreen(),
    QuestionBankScreen(),
    AdminManagementScreen(),
    DirectorDashboardScreen(),
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
              icon: Icon(Icons.library_books_rounded), label: 'Контент'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_rounded), label: 'Банк'),
          BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts_rounded), label: 'Басқару'),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded), label: 'Аналитика'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Профиль'),
        ],
      ),
    );
  }
}
