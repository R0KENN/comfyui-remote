import 'package:flutter/material.dart';
import 'home/home_screen.dart';

class ComfyRemoteApp extends StatelessWidget {
  const ComfyRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ComfyGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          surface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardColor: const Color(0xFF0A0A0A),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
