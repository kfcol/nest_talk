import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'providers/theme_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_handleThemeChange);
  }

  void _handleThemeChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nest Talk',
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Colors.blue,
          background: Colors.white,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.blue),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          background: Color(0xFF121212),
          surface: Color(0xFF121212),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF121212),
        ),
      ),
      themeMode: _themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_handleThemeChange);
    super.dispose();
  }
}
