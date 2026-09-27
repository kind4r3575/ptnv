import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../state/root_tabs.dart';
import '../theme/tokens.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/end_pod_sheet.dart';
import '../widgets/home_parts.dart';
import '../widgets/page_transitions.dart';
import '../widgets/start_time_picker_sheet.dart';
import '../widgets/tab_listenable_builder.dart';
import 'notifications_screen.dart';
import 'stock_screen.dart';

/// The Home page. Renders one of five states driven by [PodController]:
/// loading skeleton, no-active-pod, or the countdown card in its
/// on-track / grace / late variant.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller, required this.tabs});

  final PodController controller;
  final RootTabController tabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: TabListenableBuilder(
          listenable: controller,
          tabs: tabs,
          tabIndex: 0,
          builder: (context) {
            return Column(
              children: [
                const AppBarWave(),
                Expanded(child: _body(context)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: appBottomBar(context, controller, tabs, 0),
    );
  }

  /// Edit when the running pod was applied: the Material 3 modal date picker
  /// for the day, the app's usual wheels for the time. Everything the card
  /// shows is derived from the start, so saving re-anchors the whole countdown
  /// and reschedules the reminders.
  Future<void> _editStart(BuildContext context, PodSession session) async {
    final picked = await showStartTimePicker(
      context,
      initial: session.startedAt,
      confirmLabel: 'Save start time',
      footnote: (d) => 'Ends ${fmtExpiry(d.add(Duration(hours: session.durationHours)))}',
    );
    if (picked == null) return;
    // A pod can't have been applied in the future — the wheels can still land
    // there on today's date — so clamp to now rather than start the countdown
    // with negative elapsed time.
    final now = DateTime.now();
    controller.updateSessionStart(picked.isAfter(now) ? now : picked);
  }

  Widget _body(BuildContext context) {
    if (controller.isLoading) return const HomeSkeleton();

    final session = controller.session;
    if (session == null) return NoActivePodView(stock: controller.stock);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            // Scoped to just the countdown numbers, so the per-second tick
            // doesn't also rebuild EndPodButton/HomeInfoRows below — and
            // gated on the Home tab so the tick doesn't fire at all while
            // another tab is on screen (see TabListenableBuilder).
            child: TabListenableBuilder(
              listenable: controller.secondTick,
              tabs: tabs,
              tabIndex: 0,
              builder: (context) => CountdownCard(
                session: session,
                onEditStart: () => _editStart(context, session),
              ),
            ),
          ),
          const SizedBox(height: 22),
          EndPodButton(onPressed: () => showEndPodSheet(context, controller)),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: HomeInfoRows(
              stock: controller.stock,
              predictedRunOut: controller.predictedRunOut,
              reminderText: controller.reminderText,
              onReminderTap: () => Navigator.of(context).push(
                fadePushRoute(NotificationsScreen(controller: controller)),
              ),
              onStockTap: () => Navigator.of(context).push(
                fadePushRoute(StockScreen(controller: controller, tabs: tabs)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
