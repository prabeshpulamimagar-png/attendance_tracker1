import 'package:flutter/material.dart';
import 'attendance_model.dart';
import 'attendance_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendanceTrackerApp());
}

class AttendanceTrackerApp extends StatelessWidget {
  const AttendanceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const AttendanceTrackerScreen(),
    );
  }
}
