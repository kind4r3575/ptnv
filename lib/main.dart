import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'state/pod.dart';
import 'theme/tokens.dart';

void main() => runApp(const PodTrackerApp());

class PodTrackerApp extends StatefulWidget {
  const PodTrackerApp({super.key});

  @override
  State<PodTrackerApp> createState() => _PodTrackerAppState();
}

class _PodTrackerAppState extends State<PodTrackerApp> {
  final PodController _controller = PodController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pod Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          primary: AppColors.navy,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: HomeScreen(controller: _controller),
    );
  }
}
