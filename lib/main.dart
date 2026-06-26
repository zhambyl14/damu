// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'supabase_client.dart';
import 'theme.dart';
import 'providers/auth_provider.dart';
import 'providers/nav_provider.dart';
import 'navigation/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseManager.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const DamuApp());
}

class DamuApp extends StatelessWidget {
  const DamuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider()),
        ChangeNotifierProvider<NavProvider>(
            create: (_) => NavProvider()),
      ],
      child: MaterialApp(
        title: 'Damu High School',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // AppRouter барлық routing логикасын өзі шешеді
        home: const AppRouter(),
      ),
    );
  }
}