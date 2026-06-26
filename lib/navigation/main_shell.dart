// lib/navigation/main_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/nav_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/courses/courses_screen.dart';
import '../screens/tests/tests_screen.dart';
import '../screens/flashcards/flashcards_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/student/student_dashboard_screen.dart';
import '../screens/director/director_dashboard_screen.dart';
import 'curator_shell.dart';
import 'admin_shell.dart';

// ─────────────────────────────────────────────────────────
// НЕГІЗГІ МАРШРУТТАУШЫ
// ─────────────────────────────────────────────────────────
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) return const _SplashScreen();
    if (!auth.isAuthenticated) return const LoginScreen();

    final user = auth.userModel!;
    switch (user.role) {
      case UserRole.director:
        return const DirectorDashboardScreen();
      case UserRole.curator:
        return const CuratorShell();
      case UserRole.admin:
        return const AdminShell();
      case UserRole.student:
        return const StudentMainShell();
      default:
        return const LoginScreen();
    }
  }
}

// ─────────────────────────────────────────────────────────
// СТУДЕНТ ҚАБЫҒЫ — 5 ВКЛАДКАЛЫ BOTTOM NAV
// ─────────────────────────────────────────────────────────
class StudentMainShell extends StatelessWidget {
  const StudentMainShell({super.key});

  static const List<Widget> _screens = [
    StudentDashboardScreen(),
    CoursesScreen(),
    TestsScreen(),
    FlashcardsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavProvider>();
    final user = context.watch<AuthProvider>().userModel;
    final hasCoursesAccess = user?.hasCoursesAccess ?? false;
    final idx = nav.currentIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: idx, children: _screens),
      bottomNavigationBar: _BottomNav(
        currentIndex: idx,
        hasCoursesAccess: hasCoursesAccess,
        onTap: nav.setIndex,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// СТУДЕНТ BOTTOM NAVIGATION BAR
// ─────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool hasCoursesAccess;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.hasCoursesAccess,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Басты',
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.play_circle_outline_rounded,
                activeIcon: Icons.play_circle_rounded,
                label: 'Курстар',
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
                isLocked: !hasCoursesAccess,
              ),
              _NavItem(
                icon: Icons.quiz_outlined,
                activeIcon: Icons.quiz_rounded,
                label: 'Тесттер',
                index: 2,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.style_outlined,
                activeIcon: Icons.style_rounded,
                label: 'Карточка',
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Профиль',
                index: 4,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isLocked;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.isLocked = false,
  });

  bool get _selected => currentIndex == index;

  @override
  Widget build(BuildContext context) {
    final color = _selected ? AppColors.navyBlue : AppColors.textMuted;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: _selected ? 32 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                color: AppColors.navyBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _selected ? activeIcon : icon,
                  color: color,
                  size: 24,
                ),
                if (isLocked)
                  Positioned(
                    right: -5,
                    top: -4,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 7,
                        color: AppColors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    _selected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SPLASH SCREEN — жүктелу кезіндегі экран
// ─────────────────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _scaleFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );
    _textFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBlue,
      body: Stack(
        children: [
          // Декоративті шеңберлер
          Positioned(
            top: -70,
            right: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -90,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Орталық мазмұн
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Анимациялы логотип
                ScaleTransition(
                  scale: _scaleFade,
                  child: FadeTransition(
                    opacity: _scaleFade,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.white.withValues(alpha: 0.07),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.55),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            blurRadius: 32,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.school_rounded,
                          color: AppColors.gold,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Атау + ұран — анимациямен
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        const Text(
                          'DAMU HIGH SCHOOL',
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'EDUCATE  •  INSPIRE  •  EMPOWER',
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gold,
                            letterSpacing: 2.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Алтын сызық
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 1,
                              color: AppColors.gold.withValues(alpha: 0.4),
                            ),
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.gold,
                              ),
                            ),
                            Container(
                              width: 48,
                              height: 1,
                              color: AppColors.gold.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 64),

                // Жүктелу индикаторы
                FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          color: AppColors.gold.withValues(alpha: 0.85),
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Жүктелуде...',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 13,
                          color: AppColors.white.withValues(alpha: 0.45),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}