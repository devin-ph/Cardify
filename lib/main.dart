import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI English Learning - Object Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromARGB(255, 247, 236, 247), // màu nền
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Color.fromARGB(
          255,
          245,
          240,
          248,
        ), // màu nền tổng thể
        useMaterial3: true,
      ),
      home: MainScreen(),
    );
  }
}

// ...existing code...
