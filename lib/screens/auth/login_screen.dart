// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMsg;

  late AnimationController _ctrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _cardFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      await context.read<AuthProvider>().signInWithEmailAndPassword(
            _emailCtrl.text.trim(),
            _passCtrl.text,
          );
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMsg = context.read<AuthProvider>().error ??
              'Жүйеге кіру сәтсіз болды. Қайталап көріңіз.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Құпия сөзді қалпына келтіру'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Email мекенжайыңызды енгізіңіз — қалпына келтіру сілтемесі жіберіледі.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'email@mektep.kz',
                prefixIcon: Icon(Icons.email_outlined,
                    color: AppColors.navyBlue, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Болдырмау')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Жіберу'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;
    try {
      await context.read<AuthProvider>().sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Қалпына келтіру хаты жіберілді. Поштаңызды тексеріңіз.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.navyBlue,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Декоративті фон шеңберлері ─────────────────
          Positioned(
            top: -90,
            right: -90,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.3,
            left: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.04),
              ),
            ),
          ),

          // ── Негізгі мазмұн ────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // ── БРЕНД БӨЛІМІ ───────────────────
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(32, 48, 32, 32),
                        child: Column(
                          children: [
                            // Логотип
                            ScaleTransition(
                              scale: _logoScale,
                              child: FadeTransition(
                                opacity: _logoFade,
                                child: Container(
                                  width: 114,
                                  height: 114,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        AppColors.white.withValues(alpha: 0.07),
                                    border: Border.all(
                                      color: AppColors.gold
                                          .withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.18),
                                        blurRadius: 28,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(
                                      Icons.school_rounded,
                                      color: AppColors.gold,
                                      size: 52,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Мектеп атауы
                            FadeTransition(
                              opacity: _logoFade,
                              child: const Text(
                                'DAMU HIGH SCHOOL',
                                style: TextStyle(
                                  fontFamily: 'PlayfairDisplay',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.white,
                                  letterSpacing: 1.8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Ұран
                            FadeTransition(
                              opacity: _logoFade,
                              child: const Text(
                                'EDUCATE  •  INSPIRE  •  EMPOWER',
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gold,
                                  letterSpacing: 2.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Алтын бөлгіш сызық
                            FadeTransition(
                              opacity: _logoFade,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 1,
                                    color:
                                        AppColors.gold.withValues(alpha: 0.4),
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
                                    color:
                                        AppColors.gold.withValues(alpha: 0.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── ФОРМА КАРТОЧКАСЫ ───────────────
                      Expanded(
                        child: FadeTransition(
                          opacity: _cardFade,
                          child: SlideTransition(
                            position: _cardSlide,
                            child: Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(36),
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                  28, 36, 28, 32),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Тақырып
                                    Text(
                                      'Жүйеге кіру',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: AppColors.navyBlue,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Аккаунтыңызға кіріп, дайындықты жалғастырыңыз',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color:
                                                AppColors.textSecondary,
                                          ),
                                    ),

                                    const SizedBox(height: 30),

                                    // Пошта өрісі
                                    const _Label(
                                        'Электрондық пошта'),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _emailCtrl,
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      textInputAction:
                                          TextInputAction.next,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'email@mektep.kz',
                                        prefixIcon: Icon(
                                          Icons.email_outlined,
                                          color: AppColors.navyBlue,
                                          size: 20,
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null ||
                                            v.trim().isEmpty) {
                                          return 'Электрондық поштаны енгізіңіз';
                                        }
                                        if (!v.contains('@') ||
                                            !v.contains('.')) {
                                          return 'Жарамды пошта мекенжайын енгізіңіз';
                                        }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 18),

                                    // Құпия сөз өрісі
                                    const _Label('Құпия сөз'),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passCtrl,
                                      obscureText: _obscure,
                                      textInputAction:
                                          TextInputAction.done,
                                      onFieldSubmitted: (_) =>
                                          _signIn(),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '••••••••',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                          color: AppColors.navyBlue,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscure
                                                ? Icons
                                                    .visibility_outlined
                                                : Icons
                                                    .visibility_off_outlined,
                                            color: AppColors.textMuted,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                              () =>
                                                  _obscure = !_obscure),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Құпия сөзді енгізіңіз';
                                        }
                                        if (v.length < 6) {
                                          return 'Кемінде 6 таңба болуы керек';
                                        }
                                        return null;
                                      },
                                    ),

                                    // Қате хабарлама
                                    if (_errorMsg != null) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        width: double.infinity,
                                        padding:
                                            const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.error
                                              .withValues(alpha: 0.07),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppColors.error
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons
                                                  .error_outline_rounded,
                                              color: AppColors.error,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _errorMsg!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          AppColors.error,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 8),

                                    // Құпия сөзді ұмыттыңыз?
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _forgotPassword,
                                        style: TextButton.styleFrom(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 4,
                                          ),
                                        ),
                                        child: Text(
                                          'Құпия сөзді ұмыттыңыз ба?',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: AppColors.navyBlue,
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    // Кіру батырмасы
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _signIn,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.navyBlue,
                                          foregroundColor:
                                              AppColors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: AppColors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .center,
                                                children: [
                                                  Icon(
                                                      Icons.login_rounded,
                                                      size: 20),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Жүйеге кіру',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),

                                    const Spacer(),

                                    // Төменгі колонтитул
                                    Center(
                                      child: Text(
                                        '© 2025 Damu High School\nБарлық құқықтар қорғалған',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
      );
}