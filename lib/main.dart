import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_theme.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'data/datasources/local_storage_datasource.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent local storage
  final prefs = await SharedPreferences.getInstance();
  final localStorage = LocalStorageDataSource(prefs);

  runApp(
    ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(localStorage)],
      child: const TiggoMateApp(),
    ),
  );
}

class TiggoMateApp extends StatelessWidget {
  const TiggoMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TiggoMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Default to sleek automotive dark theme
      routerConfig: appRouter,
    );
  }
}
