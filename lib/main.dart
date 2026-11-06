import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/root_shell.dart';
import 'services/incoming_file_service.dart';
import 'services/notification_service.dart';
import 'state/notification_rule.dart';
import 'state/pod.dart';
import 'state/root_tabs.dart';
import 'theme/tokens.dart';
import 'widgets/backup_flows.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // required before SharedPreferences
  // Not awaited: the timezone-database parse + platform-channel round trips
  // inside init() otherwise block the first frame for several seconds on real
  // devices. It's kicked off here so it runs concurrently with app startup;
  // NotificationService.sync()/showLowStockNow() await its completion
  // internally before touching the plugin, so nothing is silently skipped.
  NotificationService.instance.init();
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<NotificationTrigger>? _tapSub;
  StreamSubscription<IncomingFile>? _fileSub;

  @override
  void initState() {
    super.initState();
    // Deep-link a notification tap to the relevant tab: while the app is
    // already alive, via the stream; on a cold launch (app was fully
    // closed), via the one-shot launch-details check. See
    // NotificationService.onTapped / consumeInitialTrigger.
    _tapSub = NotificationService.instance.onTapped.listen(_openTrigger);
    NotificationService.instance.consumeInitialTrigger().then((trigger) {
      if (trigger != null && mounted) _openTrigger(trigger);
    });

    // A backup opened from another app ("Open with Pod Tracker"), whether it
    // launched the app or arrived while it was running. Subscribed before
    // start() so a launch file isn't missed.
    _fileSub = IncomingFileService.instance.files.listen(_openIncomingFile);
    IncomingFileService.instance.start();
  }

  void _openTrigger(NotificationTrigger trigger) => _tabs.goTo(trigger.targetTab);

  Future<void> _openIncomingFile(IncomingFile file) async {
    await WidgetsBinding.instance.endOfFrame; // the navigator exists after the first frame
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await runImportFromBytes(context, _controller, file.bytes);
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    _fileSub?.cancel();
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
        // Material's date picker already inherits Poppins from [fontFamily]
        // above, but it keeps Material's own Roboto-tuned weights and letter
        // spacing, which reads as a different typeface beside the app's cards.
        // Restating each slot in [AppText]'s terms makes every calendar in the
        // app match its surroundings — Add Pod, End Pod and the Home
        // start-time editor all open this one dialog, and any future caller
        // inherits the same type from here.
        datePickerTheme: DatePickerThemeData(
          backgroundColor: AppColors.white,
          headerHelpStyle: AppText.eyebrow,
          headerHeadlineStyle: AppText.sheetTitle.copyWith(fontSize: 24),
          weekdayStyle: AppText.statLabel.copyWith(fontSize: 12, letterSpacing: 0),
          // The day/year colours come from the picker's own state-driven
          // foreground properties, so only the metrics here take effect.
          dayStyle: AppText.statValue.copyWith(fontSize: 14),
          yearStyle: AppText.statValue,
        ),
      ),
      home: RootShell(controller: _controller, tabs: _tabs),
    );
  }
}
