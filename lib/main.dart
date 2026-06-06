import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: FocusLockerApp()));
}

class FocusLockerApp extends ConsumerWidget {
  const FocusLockerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          theme.isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: theme.background,
      systemNavigationBarIconBrightness:
          theme.isDark ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp(
      title: 'Focus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: theme.isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: theme.background,
        colorScheme: ColorScheme(
          brightness: theme.isDark ? Brightness.dark : Brightness.light,
          primary: theme.accent,
          onPrimary: theme.isDark ? Colors.black : Colors.white,
          secondary: theme.surface,
          onSecondary: theme.text,
          error: Colors.red,
          onError: Colors.white,
          surface: theme.surface,
          onSurface: theme.text,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
