import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/pod.dart';
import '../theme/tokens.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/home_parts.dart';

/// The Settings screen (Figma node `213:83`). Every control in Pod Settings,
/// Notifications, Reminders and Language & Format is functional and persists on
/// [PodController] for the session. The "Data & Backup" and "About & Support"
/// rows are shown exactly per design but their taps only show "Coming soon".
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final PodController controller;

  // Cycle option sets for the value + chevron rows.
  static const List<String> _podTypes = ['Omnipod · 72h', 'Omnipod 5 · 72h', 'Dana · 72h'];
  static const List<int> _graceOptions = [1, 2, 4, 8];
  static const List<String> _snoozeOptions = ['5 min', '10 min', '15 min', '30 min'];
  static const List<String> _languages = ['English', 'Українська', 'Español'];
  static const List<String> _timeFormats = ['24-hour', '12-hour'];
  static const List<String> _dateFormats = ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'];

  static T _next<T>(List<T> options, T current) {
    final i = options.indexOf(current);
    return options[(i + 1) % options.length];
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Coming soon'),
        duration: Duration(milliseconds: 900),
      ));
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
                      _sectionHeader('Pod Settings'),
                      _card(child: _durationBlock(c)),
                      const SizedBox(height: 14),
                      _card(child: _lowStockBlock(c)),
                      const SizedBox(height: 14),
                      _card(child: _podConfigBlock(context, c)),
                      _sectionHeader('Notifications'),
                      _card(child: _notificationsBlock(c)),
                      const SizedBox(height: 14),
                      _card(child: _quietBlock(context, c)),
                      _sectionHeader('Reminders before expiry'),
                      _card(child: _remindersBlock(c)),
                      _sectionHeader('Language & Format'),
                      _card(child: _languageBlock(context, c)),
                      _sectionHeader('Data & Backup'),
                      _card(child: _dataBackupBlock(context)),
                      _sectionHeader('About & Support'),
                      _card(child: _aboutBlock(context)),
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

  // --- Section scaffolding ---------------------------------------------------

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
        child: Text(title, style: AppText.sheetTitle.copyWith(fontSize: 20)),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: AppColors.divider),
      );

  // --- Pod Settings ----------------------------------------------------------

  Widget _durationBlock(PodController c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Default Pod Duration', style: AppText.rowValue),
          const SizedBox(height: 2),
          Text('How many hours a new pod session lasts by default',
              style: AppText.sheetSubtitle),
          const SizedBox(height: 12),
          _NumberBox(
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
          _NumberBox(
            key: const ValueKey('lowStockField'),
            value: c.lowStockThreshold,
            unit: 'pods',
            onChanged: c.setLowStockThreshold,
          ),
        ],
      );

  Widget _podConfigBlock(BuildContext context, PodController c) => Column(
        children: [
          _ValueRow(
            label: 'Pod Type',
            value: c.podType,
            onTap: () => c.setPodType(_next(_podTypes, c.podType)),
          ),
          _divider(),
          _ValueRow(
            label: 'Grace Period',
            value: '${c.gracePeriodHours} hours',
            onTap: () => c.setGracePeriodHours(_next(_graceOptions, c.gracePeriodHours)),
          ),
          _divider(),
          _ToggleRow(
            label: 'Site Rotation Reminder',
            subtitle: 'Remind me to change insertion site',
            value: c.siteRotationReminder,
            onChanged: c.setSiteRotationReminder,
          ),
        ],
      );

  // --- Notifications ---------------------------------------------------------

  Widget _notificationsBlock(PodController c) => Column(
        children: [
          _ToggleRow(
            label: 'Enable Notifications',
            value: c.enableNotifications,
            onChanged: c.setEnableNotifications,
          ),
          _divider(),
          _ToggleRow(label: 'Sound', value: c.soundEnabled, onChanged: c.setSoundEnabled),
          _divider(),
          _ToggleRow(
              label: 'Vibration', value: c.vibrationEnabled, onChanged: c.setVibrationEnabled),
          _divider(),
          _ToggleRow(
            label: 'Critical Alerts',
            subtitle: 'Alert even when phone is silent',
            value: c.criticalAlerts,
            onChanged: c.setCriticalAlerts,
          ),
          _divider(),
          _ToggleRow(
            label: 'Low Stock Alert',
            subtitle: 'Notify me when pods run low',
            value: c.lowStockAlert,
            onChanged: c.setLowStockAlert,
          ),
          _divider(),
          _ToggleRow(
            label: 'Hide Previews',
            subtitle: 'Hide pod details in notifications',
            value: c.hidePreviews,
            onChanged: c.setHidePreviews,
          ),
        ],
      );

  Widget _quietBlock(BuildContext context, PodController c) => Column(
        children: [
          _ToggleRow(
            label: 'Quiet Hours',
            subtitle: '22:00 – 07:00 · alerts muted',
            value: c.quietHours,
            onChanged: c.setQuietHours,
          ),
          _divider(),
          _ValueRow(
            label: 'Snooze Duration',
            value: c.snoozeDuration,
            onTap: () => c.setSnoozeDuration(_next(_snoozeOptions, c.snoozeDuration)),
          ),
        ],
      );

  // --- Reminders -------------------------------------------------------------

  Widget _remindersBlock(PodController c) {
    final rows = <Widget>[];
    for (var i = 0; i < c.reminderHours.length; i++) {
      if (i > 0) rows.add(const SizedBox(height: 12));
      rows.add(_ReminderRow(
        index: i,
        hours: c.reminderHours[i],
        onChanged: (h) => c.updateReminder(i, h),
        onDelete: () => c.removeReminder(i),
      ));
    }
    rows.add(const SizedBox(height: 8));
    rows.add(GestureDetector(
      onTap: () => c.addReminder(12),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.cyanBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('＋ Add Reminder',
            style: AppText.rowValue.copyWith(color: AppColors.blue, fontSize: 14)),
      ),
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  // --- Language & Format -----------------------------------------------------

  Widget _languageBlock(BuildContext context, PodController c) => Column(
        children: [
          _ValueRow(
            label: 'Language',
            value: c.language,
            onTap: () => c.setLanguage(_next(_languages, c.language)),
          ),
          _divider(),
          _ValueRow(
            label: 'Time Format',
            value: c.timeFormat,
            onTap: () => c.setTimeFormat(_next(_timeFormats, c.timeFormat)),
          ),
          _divider(),
          _ValueRow(
            label: 'Date Format',
            value: c.dateFormat,
            onTap: () => c.setDateFormat(_next(_dateFormats, c.dateFormat)),
          ),
        ],
      );

  // --- Data & Backup / About (rows shown, taps = Coming soon) ----------------

  Widget _dataBackupBlock(BuildContext context) => Column(
        children: [
          _LinkRow(label: 'Export history as PDF', onTap: () => _comingSoon(context)),
          _divider(),
          _LinkRow(label: 'Export history as CSV', onTap: () => _comingSoon(context)),
          _divider(),
          _LinkRow(label: 'Clear History', onTap: () => _comingSoon(context)),
          _divider(),
          _LinkRow(label: 'Reset to Defaults', onTap: () => _comingSoon(context)),
        ],
      );

  Widget _aboutBlock(BuildContext context) => Column(
        children: [
          _LinkRow(label: 'Help & FAQ', onTap: () => _comingSoon(context)),
          _divider(),
          _LinkRow(label: 'Contact Support', onTap: () => _comingSoon(context)),
          _divider(),
          _LinkRow(label: 'Privacy Policy', onTap: () => _comingSoon(context)),
          _divider(),
          _LinkRow(label: 'Terms of Service', onTap: () => _comingSoon(context)),
          _divider(),
          _LinkRow(label: 'Rate the App', onTap: () => _comingSoon(context)),
          _divider(),
          Row(
            children: [
              Expanded(child: Text('Version', style: AppText.rowValue)),
              Text('1.0.0', style: AppText.rowTitle),
            ],
          ),
        ],
      );
}

// ===========================================================================
// Reusable row widgets
// ===========================================================================

/// A bordered number field with a right-aligned unit label (Duration, Low Stock).
class _NumberBox extends StatefulWidget {
  const _NumberBox({
    super.key,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberBox> createState() => _NumberBoxState();
}

class _NumberBoxState extends State<_NumberBox> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.value}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final v = int.tryParse(raw.trim());
    if (v != null) widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppText.rowValue.copyWith(fontSize: 18),
              onChanged: _commit,
              onSubmitted: _commit,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
          Text(widget.unit, style: AppText.rowTitle),
        ],
      ),
    );
  }
}

/// Label + value + chevron, tappable (cycles the value).
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.rowValue)),
          Text(value, style: AppText.rowTitle),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.slate, size: 22),
        ],
      ),
    );
  }
}

/// Label (+ optional subtitle) with a trailing switch.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.rowValue),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppText.sheetSubtitle),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.white,
          activeTrackColor: AppColors.blue,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Label + chevron, tappable (used for the non-functional Data/About rows).
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.rowValue)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.slate, size: 22),
        ],
      ),
    );
  }
}

/// One "Reminder N" row: a small number box + "hours before" + delete.
class _ReminderRow extends StatefulWidget {
  const _ReminderRow({
    required this.index,
    required this.hours,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final int hours;
  final ValueChanged<int> onChanged;
  final VoidCallback onDelete;

  @override
  State<_ReminderRow> createState() => _ReminderRowState();
}

class _ReminderRowState extends State<_ReminderRow> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.hours}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final v = int.tryParse(raw.trim());
    if (v != null) widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reminder ${widget.index + 1}', style: AppText.statLabel),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 64,
              height: 44,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cyan.withValues(alpha: 0.7), width: 1.5),
                ),
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: AppText.rowValue.copyWith(fontSize: 16),
                  onChanged: _commit,
                  onSubmitted: _commit,
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('hours before', style: AppText.rowTitle)),
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.endRed),
              splashRadius: 20,
            ),
          ],
        ),
      ],
    );
  }
}
