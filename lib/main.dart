import 'package:flutter/material.dart';

import 'screens/root_shell.dart';
import 'services/notification_service.dart';
import 'state/pod.dart';
import 'state/root_tabs.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // required before SharedPreferences
  await NotificationService.instance.init(); // ready before the controller boots
  runApp(const PodTrackerApp());
}

class PodTrackerApp extends StatefulWidget {
  const PodTrackerApp({super.key});

  @override
  State<PodTrackerApp> createState() => _PodTrackerAppState();
}

class _PodTrackerAppState extends State<PodTrackerApp> {
  final PodController _controller = PodController();
  final RootTabController _tabs = RootTabController();

  @override
  void dispose() {
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pod Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins', // bundled locally; see theme/tokens.dart
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          primary: AppColors.navy,
        ),
      ),
      home: RootShell(controller: _controller, tabs: _tabs),
    );
  }
}
