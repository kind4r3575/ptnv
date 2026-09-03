import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../state/root_tabs.dart';
import 'add_pod_sheet.dart';
import 'home_parts.dart';

/// The single bottom navigation bar shared by all five destinations.
///
/// Home, Stock, History and Settings live side by side inside `RootShell`'s
/// `IndexedStack` and stay mounted, so switching between them is just a
/// [RootTabController] index change — no [Navigator] push, no rebuild, no
/// transition. `StockHistoryScreen` is the one bottom-bar screen pushed on
/// top of the shell (Stock's "See all" drill-down); switching tabs from
/// there sets the tab first, then pops back to reveal the shell showing it.
Widget appBottomBar(
  BuildContext context,
  PodController controller,
  RootTabController tabs,
  int currentIndex,
) {
  void goTo(int index) {
    if (index == currentIndex) return;
    tabs.goTo(index);
    Navigator.of(context).popUntil((r) => r.isFirst);
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
