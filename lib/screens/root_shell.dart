import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../state/root_tabs.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'stock_screen.dart';

/// Hosts the four bottom-tab destinations in one [IndexedStack] so switching
/// tabs only changes which one is painted — no route push, no rebuilding the
/// destination from scratch, no fade transition — and each tab keeps its
/// scroll position and local state between visits. Previously every tab
/// switch pushed (or replaced) a full new route, which is why switching felt
/// janky: a whole new screen was being built and animated in each time.
class RootShell extends StatelessWidget {
  const RootShell({super.key, required this.controller, required this.tabs});

  final PodController controller;
  final RootTabController tabs;

  // Maps a nav index (0/1/3/4) to its slot in the IndexedStack below.
  static const _stackOf = [0, 1, 3, 4];

  @override
  Widget build(BuildContext context) {
    // Built once per RootShell.build() call (i.e. essentially once for the
    // app's lifetime) and captured by the closure below, so the same widget
    // *instances* are reused across every tab switch. That lets Flutter's
    // `identical(oldWidget, newWidget)` fast path skip rebuilding the three
    // screens that aren't switching — without this, a fresh instance of all
    // four screens was created on every ListenableBuilder rebuild, forcing
    // every tab's build() to re-run each time any tab was tapped.
    final screens = [
      HomeScreen(controller: controller, tabs: tabs),
      StockScreen(controller: controller, tabs: tabs),
      HistoryScreen(controller: controller, tabs: tabs),
      SettingsScreen(controller: controller, tabs: tabs),
    ];
    return ListenableBuilder(
      listenable: tabs,
      builder: (context, _) => IndexedStack(
        index: _stackOf.indexOf(tabs.index),
        children: screens,
      ),
    );
  }
}
