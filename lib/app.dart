import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home/home_screen.dart';

class ComfyRemoteApp extends StatelessWidget {
  const ComfyRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: 'ComfyGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.dark,
          surface: Colors.black,
          onSurface: const Color(0xFFF2F2F7),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardColor: const Color(0xFF080809),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF0A0A0C),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1C1C1E),
          contentTextStyle: const TextStyle(color: Color(0xFFF2F2F7)),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
