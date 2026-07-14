import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../theme/tokens.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/home_parts.dart';
import '../widgets/settings_parts.dart';
import 'notifications_screen.dart';
import 'pod_settings_screen.dart';

/// The Settings screen (Figma node `213:83`). Pod Settings and Notifications are
/// their own pushed pages; Language & Format is functional inline and persists on
/// [PodController]. The "Data & Backup" and "About & Support" rows are shown per
/// design — the export/about taps only show "Coming soon", while Clear History
/// and Reset to Defaults are live destructive actions.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final PodController controller;

  static const List<String> _languages = ['English'];
  static const List<String> _timeFormats = ['12-hour', '24-hour'];
  static const List<String> _dateFormats = [
    'DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD',
    'DD.MM.YYYY', 'MM.DD.YYYY', 'YYYY.MM.DD',
  ];

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Coming soon'),
        duration: Duration(milliseconds: 900),
      ));
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

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
                  title: 'Settings',
                  leading: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                    splashRadius: 22,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      const SettingsSectionHeader('Pod Settings'),
                      SettingsCard(
                        child: SettingsLinkRow(
                          label: 'Pod Settings',
                          onTap: () =>
                              _push(context, PodSettingsScreen(controller: controller)),
                        ),
                      ),
                      const SettingsSectionHeader('Notifications'),
                      SettingsCard(
                        child: SettingsLinkRow(
                          label: 'Manage Notifications',
                          onTap: () =>
                              _push(context, NotificationsScreen(controller: controller)),
                        ),
                      ),
                      const SettingsSectionHeader('Language & Format'),
                      SettingsCard(child: _languageBlock(context, c)),
                      const SettingsSectionHeader('Data & Backup'),
                      SettingsCard(child: _dataBackupBlock(context, c)),
                      const SettingsSectionHeader('About & Support'),
                      SettingsCard(child: _aboutBlock(context)),
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
      bottomNavigationBar: appBottomBar(context, controller, 4),
    );
  }

  // --- Language & Format -----------------------------------------------------

  Widget _languageBlock(BuildContext context, PodController c) => Column(
        children: [
          SettingsValueRow(
            label: 'Language',
            value: c.language,
            onTap: () => pickStringOption(context,
                title: 'Language',
                subtitle: 'Choose the app language.',
                options: _languages,
                current: c.language,
                onPicked: c.setLanguage),
          ),
          const SettingsDivider(),
          SettingsValueRow(
            label: 'Time Format',
            value: c.timeFormat,
            onTap: () => pickStringOption(context,
                title: 'Time Format',
                subtitle: 'How times are displayed.',
                options: _timeFormats,
                current: c.timeFormat,
                onPicked: c.setTimeFormat),
          ),
          const SettingsDivider(),
          SettingsValueRow(
            label: 'Date Format',
            value: c.dateFormat,
            onTap: () => pickStringOption(context,
                title: 'Date Format',
                subtitle: 'How dates are displayed.',
                options: _dateFormats,
                current: c.dateFormat,
                onPicked: c.setDateFormat),
          ),
        ],
      );

  // --- Data & Backup / About -------------------------------------------------

  Widget _dataBackupBlock(BuildContext context, PodController c) => Column(
        children: [
          SettingsLinkRow(label: 'Export history as PDF', onTap: () => _comingSoon(context)),
          const SettingsDivider(),
          SettingsLinkRow(label: 'Export history as CSV', onTap: () => _comingSoon(context)),
          const SettingsDivider(),
          SettingsLinkRow(
            label: 'Clear History',
            color: AppColors.endRed,
            onTap: () async {
              final ok = await showConfirmDialog(
                context: context,
                title: 'Clear History?',
                message:
                    'This permanently removes every past pod session from your history. This cannot be undone.',
                confirmLabel: 'Clear',
                destructive: true,
              );
              if (ok == true) c.clearHistory();
            },
          ),
          const SettingsDivider(),
          SettingsLinkRow(
            label: 'Reset to Defaults',
            color: AppColors.endRed,
            onTap: () async {
              final ok = await showConfirmDialog(
                context: context,
                title: 'Reset to Defaults?',
                message:
                    'All Pod, Notification and Language settings return to their defaults. Your stock and history are kept.',
                confirmLabel: 'Reset',
              );
              if (ok == true) c.resetToDefaults();
            },
          ),
        ],
      );

  Widget _aboutBlock(BuildContext context) => Column(
        children: [
          SettingsLinkRow(label: 'Help & FAQ', onTap: () => _comingSoon(context)),
          const SettingsDivider(),
          SettingsLinkRow(label: 'Contact Support', onTap: () => _comingSoon(context)),
          const SettingsDivider(),
          SettingsLinkRow(label: 'Privacy Policy', onTap: () => _comingSoon(context)),
          const SettingsDivider(),
          SettingsLinkRow(label: 'Terms of Service', onTap: () => _comingSoon(context)),
          const SettingsDivider(),
          SettingsLinkRow(label: 'Rate the App', onTap: () => _comingSoon(context)),
          const SettingsDivider(),
          Row(
            children: [
              Expanded(child: Text('Version', style: AppText.rowValue)),
              Text('1.0.0', style: AppText.rowTitle),
            ],
          ),
        ],
      );
}
