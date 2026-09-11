import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/settings_parts.dart';
import '../widgets/simple_page.dart';

/// Help & FAQ (Settings → About & Support). Grouped, expandable answers
/// grounded in what the app actually does — no external help site, in
/// keeping with Pod Tracker being fully offline.
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  static const List<(String, List<(String, String)>)> _groups = [
    (
      'Pod Sessions',
      [
        (
          'How does the countdown work?',
          'Each pod counts down from when you start it to its rated wear time '
              '(72 hours by default). The card shows three states: On Track while '
              "it's within that window, Grace once it passes rated wear time but is "
              'still within the grace period you\'ve set, and Not Delivering once '
              'the grace period ends too.',
        ),
        (
          'Can I change how long a pod lasts?',
          'Yes — pod duration and grace period are both configurable in Pod '
              'Settings, and apply the next time you start a pod.',
        ),
        (
          'What happens if I start a new pod while one is already active?',
          'Pod Tracker asks you to confirm the swap. If you go ahead, the current '
              'pod is closed out and saved to your history as "Replaced" — nothing '
              'is discarded.',
        ),
        (
          'Can I log a pod I already started earlier today?',
          'Yes — the Start Pod flow includes a custom start-time picker, so a pod '
              'you applied earlier can be logged with its real start time instead '
              'of "now".',
        ),
      ],
    ),
    (
      'Stock & History',
      [
        (
          'How is my pod stock tracked?',
          'Stock goes up or down as you tap +/-, and rapid taps are combined into '
              'a single log entry rather than spamming your activity log. Use "Set '
              'exact amount" to reconcile stock by hand, or "Undo" to reverse the '
              'last change.',
        ),
        (
          'How is the run-out date calculated?',
          'Pod Tracker estimates your days of supply and a projected run-out date '
              'from your recent usage pattern and current stock — it updates '
              'automatically as stock and history change.',
        ),
        (
          "What's recorded in Session History?",
          'Every finished pod: its start and end time, actual wear duration, '
              'insertion site, and outcome — completed on time, ended early, or '
              'worn too long.',
        ),
        (
          'Does clearing history affect my stock or settings?',
          'No — "Clear History" (Settings → Data & Backup) only removes session '
              'history. Stock and settings are untouched.',
        ),
      ],
    ),
    (
      'Notifications',
      [
        (
          'What kinds of reminders can I set?',
          "Rules can fire before a pod's expiry, at the start or end of its grace "
              'period, when stock runs low, as a daily check-in, or as a recurring '
              'site-rotation reminder. Add, edit, or remove as many as you like — '
              'each one is independent.',
        ),
        (
          'Will reminders still fire if I restart my phone?',
          'Yes — Pod Tracker requests permission to run after a reboot '
              'specifically so scheduled reminders survive a restart instead of '
              'silently disappearing.',
        ),
        (
          'Can I silence notifications overnight?',
          'Yes — quiet hours, snooze duration, sound, vibration, and hidden '
              'previews are all configurable in Settings → Notifications.',
        ),
      ],
    ),
    (
      'Privacy & Data',
      [
        (
          'Does Pod Tracker use the internet or send my data anywhere?',
          "No. The Android app doesn't even request the INTERNET permission, so "
              "it's architecturally unable to make a network call. Everything — "
              'stock, history, notification rules, settings — lives only on your '
              'device. See the full Privacy Policy for details.',
        ),
        (
          'Do I need an account?',
          'No accounts, no sign-in, and nothing tied to your identity — Pod '
              'Tracker works the same from the moment you install it.',
        ),
        (
          'What does "Reset to Defaults" actually reset?',
          'Pod, Notification, and Language/Format settings return to their '
              'factory defaults. Your stock and session history are kept.',
        ),
      ],
    ),
    (
      'About',
      [
        (
          'Is Pod Tracker affiliated with Omnipod or Insulet?',
          "No — it's an independent, solo-developed project, not affiliated with "
              'or endorsed by Insulet, Omnipod, or any other pump manufacturer.',
        ),
        (
          'Is this a substitute for medical advice?',
          "No — Pod Tracker is a personal organizer, not a medical device. Always "
              "follow your pump's own instructions and your healthcare team's "
              'guidance; see Terms of Service for the full disclaimer.',
        ),
        (
          'I found a bug or have an idea — where do I send it?',
          'Through Contact Support, right below this — it opens the GitHub '
              'Issues page for the project.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: 'Help & FAQ',
      children: [
        for (final group in _groups) ...[
          SettingsSectionHeader(group.$1),
          SettingsCard(
            child: Column(
              children: [
                for (var i = 0; i < group.$2.length; i++) ...[
                  if (i > 0) const SettingsDivider(),
                  _FaqTile(question: group.$2[i].$1, answer: group.$2[i].$2),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Expanded(child: Text(widget.question, style: AppText.docHeading)),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.slate, size: 22),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(widget.answer, style: AppText.docBody),
          ),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}
