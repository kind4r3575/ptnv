import 'package:flutter/foundation.dart';

/// Which bottom-tab destination is showing inside [RootShell]'s
/// `IndexedStack`: 0 Home, 1 Stock, 3 History, 4 Settings (2 is the center
/// Add button, not a tab — see `HomeBottomBar`). Shared with every screen
/// that renders the bottom bar, including ones pushed on top of the shell
/// (e.g. `StockHistoryScreen`), so tapping a tab from anywhere just flips
/// this index instead of pushing a new route.
class RootTabController extends ChangeNotifier {
  int index = 0;

  void goTo(int value) {
    if (value == index) return;
    index = value;
    notifyListeners();
  }
}
