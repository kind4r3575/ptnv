import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../theme/tokens.dart';
import '../widgets/home_parts.dart';
import '../widgets/option_picker_sheet.dart';
import '../widgets/settings_parts.dart';

/// The Pod Settings screen — Default Pod Duration, Low Stock Threshold, Pod Type
/// and Grace Period. Pushed from the "Pod Settings" row in [SettingsScreen]
/// (a detail page with a back button, no bottom bar).
class PodSettingsScreen extends StatelessWidget {
  const PodSettingsScreen({super.key, required this.controller});

  final PodController controller;

  static const List<String> _podTypes = ['Omnipod · 72h', 'Omnipod 5 · 72h', 'Dana · 72h'];
  static const List<int> _graceOptions = [0, 1, 2, 4, 8];

  static String _graceLabel(int h) =>
      h == 0 ? 'None' : (h == 1 ? '1 hour' : '$h hours');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final c = controller;
            return Column(
              children: [
                AppBarWave(
                  title: 'Pod Settings',
                  leading: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                    splashRadius: 22,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      SettingsCard(child: _durationBlock(c)),
                      const SizedBox(height: 14),
                      SettingsCard(child: _lowStockBlock(c)),
                      const SizedBox(height: 14),
                      SettingsCard(child: _podConfigBlock(context, c)),
                      const SizedBox(height: 20),
                      Center(
                        child: Text('✓ Changes are saved automatically',
                            style: AppText.caption.copyWith(color: AppColors.green)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _durationBlock(PodController c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Default Pod Duration', style: AppText.rowValue),
          const SizedBox(height: 2),
          Text('How many hours a new pod session lasts by default',
              style: AppText.sheetSubtitle),
          const SizedBox(height: 12),
          SettingsNumberBox(
            key: const ValueKey('durationField'),
            value: c.defaultPodDurationHours,
            unit: 'hours',
            onChanged: c.setDefaultPodDuration,
          ),
        ],
      );

  Widget _lowStockBlock(PodController c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Low Stock Threshold', style: AppText.rowValue),
          const SizedBox(height: 2),
          Text('Warn me when pods in stock fall below this number',
              style: AppText.sheetSubtitle),
          const SizedBox(height: 12),
          SettingsNumberBox(
            key: const ValueKey('lowStockField'),
            value: c.lowStockThreshold,
            unit: 'pods',
            onChanged: c.setLowStockThreshold,
          ),
        ],
      );

  Widget _podConfigBlock(BuildContext context, PodController c) => Column(
        children: [
          SettingsValueRow(
            label: 'Pod Type',
            value: c.podType,
            onTap: () => pickStringOption(context,
                title: 'Pod Type',
                subtitle: 'Choose your pod model and default wear time.',
                options: _podTypes,
                current: c.podType,
                onPicked: c.setPodType),
          ),
          const SettingsDivider(),
          SettingsValueRow(
            label: 'Grace Period',
            value: _graceLabel(c.gracePeriodHours),
            onTap: () async {
              final picked = await showOptionPickerSheet<int>(
                context: context,
                title: 'Grace period',
                subtitle:
                    'Keep showing the pod as usable for a short time after it expires.',
                options: _graceOptions,
                selected: c.gracePeriodHours,
                labelOf: _graceLabel,
              );
              if (picked != null) c.setGracePeriodHours(picked);
            },
          ),
        ],
      );
}
