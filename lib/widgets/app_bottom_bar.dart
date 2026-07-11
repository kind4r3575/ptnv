import 'package:flutter/material.dart';

import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/stock_screen.dart';
import '../state/pod.dart';
import 'add_pod_sheet.dart';
import 'home_parts.dart';

/// The single bottom navigation bar shared by all five destinations, wired so
/// the user can reach any screen from any other screen.
///
/// Home is the navigation root; Stock (1), History (3) and Settings (4) are
/// pushed on top of it. Switching between two secondary screens uses
/// [NavigatorState.pushReplacement] so the back stack never grows past
/// `Home → <one secondary>` — tapping Home always returns with a single
/// `popUntil` to the first route.
Widget appBottomBar(
  BuildContext context,
  PodController controller,
  int currentIndex,
) {
  Widget screenFor(int index) {
    switch (index) {
      case 1:
        return StockScreen(controller: controller);
      case 3:
        return HistoryScreen(controller: controller);
      case 4:
        return SettingsScreen(controller: controller);
      default:
        throw ArgumentError('No secondary screen for tab index $index');
    }
  }

  // A fade is direction-agnostic, so navigating up to a tab (push) and back to
  // Home (pop) animate identically — every tab switch looks the same.
  Route<void> fadeRoute(Widget page) => PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      );

  void goTo(int index) {
    if (index == currentIndex) return;
    final nav = Navigator.of(context);
    if (index == 0) {
      nav.popUntil((r) => r.isFirst); // pops the fade route → fades back to Home
      return;
    }
    final route = fadeRoute(screenFor(index));
    if (currentIndex == 0) {
      nav.push(route);
    } else {
      nav.pushReplacement(route);
    }
  }

  return HomeBottomBar(
    selectedIndex: currentIndex,
    onAddTap: () => showAddPodSheet(context, controller),
    onHomeTap: () => goTo(0),
    onStockTap: () => goTo(1),
    onHistoryTap: () => goTo(3),
    onSettingsTap: () => goTo(4),
  );
}
