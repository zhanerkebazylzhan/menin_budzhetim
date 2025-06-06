import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';

void main() {
  runApp(const MyBudgetApp());
}

class MyBudgetApp extends StatelessWidget {
  const MyBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Менің Бюджетім',
      debugShowCheckedModeBanner: false,
      
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green.shade700,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}