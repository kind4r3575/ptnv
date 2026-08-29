import 'package:flutter/material.dart';

import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/stock_screen.dart';
import '../state/pod.dart';
import 'add_pod_sheet.dart';
import 'home_parts.dart';
import 'page_transitions.dart';

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

  void goTo(int index) {
    if (index == currentIndex) return;
    final nav = Navigator.of(context);
    if (index == 0) {
      nav.popUntil((r) => r.isFirst); // pops the fade route → fades back to Home
      return;
    }
    final route = fadePushRoute(screenFor(index));
    if (currentIndex == 0) {
      nav.push(route);
    } else {
      nav.pushReplacement(route);
    }
  }

  // If the Add Pod sheet was opened with no pods left, it resolves to 'stock'
  // (the user tapped "Go to Stock") — switch to the Stock tab so they restock.
  Future<void> onAddTap() async {
    final result = await showAddPodSheet(context, controller);
    if (result == 'stock' && context.mounted) goTo(1);
  }

  return HomeBottomBar(
    selectedIndex: currentIndex,
    onAddTap: onAddTap,
    onHomeTap: () => goTo(0),
    onStockTap: () => goTo(1),
    onHistoryTap: () => goTo(3),
    onSettingsTap: () => goTo(4),
  );
}
