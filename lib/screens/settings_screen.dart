import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import '../services/link_service.dart';
import '../state/pod.dart';
import '../state/root_tabs.dart';
import '../theme/tokens.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/home_parts.dart';
import '../widgets/page_transitions.dart';
import '../widgets/settings_parts.dart';
import '../widgets/tab_listenable_builder.dart';
import 'contact_support_screen.dart';
import 'help_faq_screen.dart';
import 'notifications_screen.dart';
import 'pod_settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

/// The Settings screen (Figma node `213:83`). Pod Settings and Notifications are
/// their own pushed pages; Language & Format is functional inline and persists on
/// [PodController]. "Data & Backup" covers both a full app-state backup/restore
/// (JSON, via [BackupService] — Pod Tracker's manual stand-in for cloud sync) and
/// history-only export (CSV/PDF, via [ExportService]), plus the destructive Clear
/// History / Reset to Defaults actions. "About & Support" is fully wired: Help &
/// FAQ, Privacy Policy and Terms of Service are in-app pages; Contact Support opens
/// GitHub Issues; Rate the App opens the store listing once [AppConfig.isPublished]
/// is flipped, and shows "Coming soon" until then.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller, required this.tabs});

  final PodController controller;
  final RootTabController tabs;

  static const List<String> _languages = ['English'];
  static const List<String> _timeFormats = ['12-hour', '24-hour'];
  static const List<String> _dateFormats = [
    'DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD',
    'DD.MM.YYYY', 'MM.DD.YYYY', 'YYYY.MM.DD',
  ];

  void _toast(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(milliseconds: 900),
      ));
  }

  Future<void> _exportCsv(BuildContext context, PodController c) async {
    if (c.history.isEmpty) {
      _toast(context, 'No session history to export yet.');
      return;
    }
    try {
      await ExportService.exportCsv(c.history);
    } catch (_) {
      if (context.mounted) _toast(context, 'Export failed. Please try again.');
    }
  }

  Future<void> _exportPdf(BuildContext context, PodController c) async {
    if (c.history.isEmpty) {
      _toast(context, 'No session history to export yet.');
      return;
    }
    try {
      await ExportService.exportPdf(c.history);
    } catch (_) {
      if (context.mounted) _toast(context, 'Export failed. Please try again.');
    }
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(fadePushRoute(page));
  }

  Future<void> _backupData(BuildContext context, PodController c) async {
    try {
      await BackupService.exportBackup(c);
    } catch (_) {
      if (context.mounted) _toast(context, 'Backup failed. Please try again.');
    }
  }

  Future<void> _restoreBackup(BuildContext context, PodController c) async {
    ParsedBackup? backup;
    try {
      backup = await BackupService.pickBackup();
    } catch (e) {
      if (context.mounted) {
        _toast(context, e is FormatException ? e.message : "Couldn't read that file.",
            duration: const Duration(seconds: 3));
      }
      return;
    }
    if (backup == null) return; // user cancelled the picker
    if (!context.mounted) return;

    final ok = await showConfirmDialog(
      context: context,
      title: 'Restore Backup?',
      message: 'This replaces all current stock, history, settings and reminders with '
          '${_describeBackup(backup)}. This cannot be undone.',
      confirmLabel: 'Restore',
      destructive: true,
    );
    if (ok != true) return;

    try {
      c.restoreFromBackupJson(backup.data);
      if (context.mounted) _toast(context, 'Backup restored.');
    } catch (_) {
      if (context.mounted) {
        _toast(context, "That backup file is damaged and couldn't be restored.",
            duration: const Duration(seconds: 3));
      }
    }
  }

  String _describeBackup(ParsedBackup b) {
    final when = b.exportedAt == null ? 'a backup' : 'the backup from ${fmtFullDate(b.exportedAt!)}';
    final sessions = '${b.historyCount} session${b.historyCount == 1 ? '' : 's'}';
    final activity = '${b.activityCount} activity ${b.activityCount == 1 ? 'entry' : 'entries'}';
    return '$when ($sessions, $activity)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: TabListenableBuilder(
          listenable: controller,
          tabs: tabs,
          tabIndex: 4,
          builder: (context) {
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
      bottomNavigationBar: appBottomBar(context, controller, tabs, 4),
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
          SettingsLinkRow(label: 'Back Up Data', onTap: () => _backupData(context, c)),
          const SettingsDivider(),
          SettingsLinkRow(
            label: 'Restore Backup',
            color: AppColors.endRed,
            onTap: () => _restoreBackup(context, c),
          ),
          const SettingsDivider(),
          SettingsLinkRow(label: 'Export history as PDF', onTap: () => _exportPdf(context, c)),
          const SettingsDivider(),
          SettingsLinkRow(label: 'Export history as CSV', onTap: () => _exportCsv(context, c)),
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
          SettingsLinkRow(
              label: 'Help & FAQ', onTap: () => _push(context, const HelpFaqScreen())),
          const SettingsDivider(),
          SettingsLinkRow(
              label: 'Contact Support',
              onTap: () => _push(context, const ContactSupportScreen())),
          const SettingsDivider(),
          SettingsLinkRow(
              label: 'Privacy Policy',
              onTap: () => _push(context, const PrivacyPolicyScreen())),
          const SettingsDivider(),
          SettingsLinkRow(
              label: 'Terms of Service',
              onTap: () => _push(context, const TermsOfServiceScreen())),
          const SettingsDivider(),
          SettingsLinkRow(label: 'Rate the App', onTap: () => _rateApp(context)),
          const SettingsDivider(),
          Row(
            children: [
              Expanded(child: Text('Version', style: AppText.rowValue)),
              Text('1.0.0', style: AppText.rowTitle),
            ],
          ),
        ],
      );

  Future<void> _rateApp(BuildContext context) async {
    if (!AppConfig.isPublished) {
      _toast(context, "Coming soon — thanks for wanting to rate it!");
      return;
    }
    await LinkService.openStoreListing(context);
  }
}
