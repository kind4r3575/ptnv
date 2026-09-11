import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'settings_parts.dart';
import 'simple_page.dart';

/// One heading + body pair within a [LegalDocPage].
class LegalSection {
  const LegalSection(this.heading, this.body);

  final String heading;
  final String body;
}

/// Shared layout for Privacy Policy / Terms of Service: an intro paragraph
/// followed by one card per section, matching the Settings screen's card
/// styling so these read as part of the same app rather than a bolted-on
/// legal page.
class LegalDocPage extends StatelessWidget {
  const LegalDocPage({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String lastUpdated;
  final String intro;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: title,
      children: [
        Text('Last updated: $lastUpdated', style: AppText.caption),
        const SizedBox(height: 12),
        Text(intro, style: AppText.docBody),
        const SizedBox(height: 20),
        for (final s in sections) ...[
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.heading, style: AppText.docHeading),
                const SizedBox(height: 8),
                Text(s.body, style: AppText.docBody),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
