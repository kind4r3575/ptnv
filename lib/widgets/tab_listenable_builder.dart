import 'package:flutter/material.dart';

import '../state/root_tabs.dart';

/// Like [ListenableBuilder], but only rebuilds while [tabIndex] is the active
/// tab in [tabs] — plus once more the instant it becomes active again.
///
/// `RootShell` keeps all four tab screens mounted in an `IndexedStack` so
/// switching tabs is instant, but that means every one of them is still
/// subscribed to [listenable] even while offstage: a plain `ListenableBuilder`
/// would rebuild (and get laid out by the `IndexedStack`) all four screens on
/// every single [listenable] notification, not just the one actually on
/// screen. Home is the worst case — its countdown ticks every second — so
/// without this an inactive Home would still rebuild once a second forever.
///
/// Skipping rebuilds while inactive is safe because an offstage `IndexedStack`
/// child is never painted, so a stale build is invisible; the catch-up
/// rebuild on activation (via the [tabs] listener) guarantees the tab always
/// shows current data the moment it's revealed, with no user-visible lag.
///
/// Only correct for a screen that is *exclusively* reached by switching
/// [tabs] to [tabIndex] — i.e. one of the four widgets `RootShell` puts
/// directly in its `IndexedStack`. A screen that can also be reached by
/// pushing a second instance on top of the shell (e.g. `StockScreen`, pushed
/// from Home's "Stock" info row without changing `tabs.index`) must keep
/// using a plain `ListenableBuilder`: [tabIndex] matching [tabs].index would
/// then no longer mean "this instance is the one on screen."
class TabListenableBuilder extends StatefulWidget {
  const TabListenableBuilder({
    super.key,
    required this.listenable,
    required this.tabs,
    required this.tabIndex,
    required this.builder,
  });

  final Listenable listenable;
  final RootTabController tabs;
  final int tabIndex;
  final WidgetBuilder builder;

  @override
  State<TabListenableBuilder> createState() => _TabListenableBuilderState();
}

class _TabListenableBuilderState extends State<TabListenableBuilder> {
  bool get _active => widget.tabs.index == widget.tabIndex;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onSourceChanged);
    widget.tabs.addListener(_onTabsChanged);
  }

  @override
  void didUpdateWidget(covariant TabListenableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onSourceChanged);
      widget.listenable.addListener(_onSourceChanged);
    }
    if (oldWidget.tabs != widget.tabs) {
      oldWidget.tabs.removeListener(_onTabsChanged);
      widget.tabs.addListener(_onTabsChanged);
    }
  }

  void _onSourceChanged() {
    if (_active) setState(() {});
  }

  // Fires on every tab switch, not just into this one; only act when the
  // switch lands here, catching up on whatever was skipped while inactive.
  void _onTabsChanged() {
    if (_active) setState(() {});
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onSourceChanged);
    widget.tabs.removeListener(_onTabsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
