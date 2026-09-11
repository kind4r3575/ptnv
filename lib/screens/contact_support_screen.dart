import 'package:flutter/material.dart';

import '../services/link_service.dart';
import '../theme/tokens.dart';
import '../widgets/settings_parts.dart';
import '../widgets/simple_page.dart';

/// Contact Support (Settings → About & Support). Pod Tracker has no backend
/// and no support inbox, so this routes to the project's public GitHub
/// Issues — the one real, already-existing destination for a solo,
/// open-source app.
class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: 'Contact Support',
      children: [
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.forum_outlined, color: AppColors.blue, size: 30),
              const SizedBox(height: 12),
              Text('Need a hand?', style: AppText.sheetTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                'Pod Tracker is a solo, open-source project with no backend and no '
                'support team behind it — bugs, questions, and feature requests all go '
                "through GitHub Issues on the public repository. Before filing a new "
                "one, it's worth a quick check that it isn't already reported.",
                style: AppText.docBody,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.bug_report_outlined,
          label: 'Open GitHub Issues',
          onTap: () => LinkService.openGitHubIssues(context),
        ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: Icons.code_rounded,
          label: 'View Source on GitHub',
          filled: false,
          onTap: () => LinkService.openGitHubRepo(context),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.blue : AppColors.white;
    final fg = filled ? AppColors.white : AppColors.blue;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(color: AppColors.cyan.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 10),
            Text(label, style: AppText.button.copyWith(fontSize: 15, color: fg)),
          ],
        ),
      ),
    );
  }
}
