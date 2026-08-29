import 'package:flutter/material.dart';

import '../state/notification_rule.dart';
import '../state/pod.dart';
import '../theme/tokens.dart';
import '../widgets/app_switch.dart';
import '../widgets/home_parts.dart';
import '../widgets/option_picker_sheet.dart';
import '../widgets/page_transitions.dart';
import 'notification_edit_screen.dart';

/// The dedicated Notifications editor (reached from Settings and the Home
/// "Next Reminder" card). Lists every editable [NotificationRule] plus the
/// global delivery toggles, and opens [NotificationEditScreen] to add/edit one.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.controller});

  final PodController controller;

  static const List<String> _snoozeOptions = ['5 min', '10 min', '15 min', '30 min'];

  void _openEditor(BuildContext context, {NotificationRule? rule}) {
    Navigator.of(context).push(
      fadePushRoute(NotificationEditScreen(controller: controller, rule: rule)),
    );
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
                  title: 'Notifications',
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
                      _sectionHeader('Delivery'),
                      _card(child: _deliveryBlock(context, c)),
                      _sectionHeader('Your notifications'),
                      _card(child: _rulesBlock(context, c)),
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

  // --- Delivery (global toggles) ---------------------------------------------

  Widget _deliveryBlock(BuildContext context, PodController c) => Column(
        children: [
          _ToggleRow(
            label: 'Enable Notifications',
            subtitle: 'Master switch for all reminders',
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
            label: 'Hide Previews',
            subtitle: 'Hide pod details in notifications',
            value: c.hidePreviews,
            onChanged: c.setHidePreviews,
          ),
          _divider(),
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
            onTap: () async {
              final picked = await showOptionPickerSheet<String>(
                context: context,
                title: 'Snooze Duration',
                subtitle: 'How long to wait before reminding you again.',
                options: _snoozeOptions,
                selected: c.snoozeDuration,
                labelOf: (v) => v,
              );
              if (picked != null) c.setSnoozeDuration(picked);
            },
          ),
        ],
      );

  // --- Rules -----------------------------------------------------------------

  Widget _rulesBlock(BuildContext context, PodController c) {
    final rules = c.rules;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rules.isEmpty)
          _emptyState()
        else
          for (var i = 0; i < rules.length; i++) ...[
            if (i > 0) _divider(),
            _RuleRow(
              rule: rules[i],
              onTap: () => _openEditor(context, rule: rules[i]),
              onToggle: (v) => c.toggleRule(rules[i].id, v),
            ),
          ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _openEditor(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cyanBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('＋ Add notification',
                style: AppText.rowValue.copyWith(color: AppColors.blue, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.cyanBg, shape: BoxShape.circle),
              child: const Icon(Icons.notifications_none_rounded, size: 30, color: AppColors.blue),
            ),
            const SizedBox(height: 12),
            Text('No notifications yet', style: AppText.rowValue.copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text('Add one to be reminded before a pod expires, when stock runs low, '
                'or at a time of day.',
                textAlign: TextAlign.center, style: AppText.sheetSubtitle),
          ],
        ),
      );

  // --- Scaffolding -----------------------------------------------------------

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
}

/// One notification rule: situation icon, title + generated summary, and a
/// switch to enable/disable it. Tapping the row opens the full-screen editor.
class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.onTap, required this.onToggle});

  final NotificationRule rule;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final dim = !rule.enabled;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.cyanBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(rule.trigger.icon,
                size: 20, color: dim ? AppColors.slate : AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(rule.displayTitle,
                    style: AppText.rowValue.copyWith(
                        color: dim ? AppColors.slate : AppColors.navy)),
                const SizedBox(height: 2),
                Text(rule.summary, style: AppText.sheetSubtitle),
              ],
            ),
          ),
          AppSwitch(value: rule.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}

/// Label (+ optional subtitle) with a trailing switch (local to this screen).
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
        AppSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// Label + value + chevron, tappable (local to this screen).
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
