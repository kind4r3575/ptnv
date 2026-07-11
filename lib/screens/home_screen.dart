import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../theme/tokens.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/end_pod_sheet.dart';
import '../widgets/home_parts.dart';

/// The Home page. Renders one of five states driven by [PodController]:
/// loading skeleton, no-active-pod, or the countdown card in its
/// on-track / grace / late variant.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final PodController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([controller, controller.secondTick]),
          builder: (context, _) {
            return Column(
              children: [
                AppBarWave(onLongPressTitle: controller.cycleDemoState),
                Expanded(child: _body(context)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: appBottomBar(context, controller, 0),
    );
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
            child: CountdownCard(session: session),
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
            ),
          ),
        ],
      ),
    );
  }
}
