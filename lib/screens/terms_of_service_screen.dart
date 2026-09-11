import 'package:flutter/material.dart';

import '../widgets/legal_doc.dart';

/// Terms of Service (Settings → About & Support). Standard terms for a free,
/// solo-developed, offline app, plus the medical disclaimer that a pod-wear
/// tracker genuinely needs — Pod Tracker is an organizer, not a medical
/// device, and isn't affiliated with any pump manufacturer.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocPage(
      title: 'Terms of Service',
      lastUpdated: 'September 11, 2026',
      intro: 'These terms cover your use of Pod Tracker. They are deliberately short, '
          "in keeping with a small, free, solo-developed app.",
      sections: [
        LegalSection(
          'Acceptance of terms',
          "By downloading or using Pod Tracker, you agree to these terms. If you don't "
              "agree, please don't use the app.",
        ),
        LegalSection(
          'What Pod Tracker is',
          'Pod Tracker is a free, offline tool for tracking patch-pump wear time, stock, '
              'and session history. It is a personal organizer, not a medical device, and '
              'it is not reviewed, certified, or approved by any regulatory body.',
        ),
        LegalSection(
          'Medical disclaimer',
          'Pod Tracker is not a substitute for professional medical advice, diagnosis, or '
              'treatment. Always follow the instructions provided with your pump or pod '
              "and the guidance of your healthcare team. Don't start, stop, or change your "
              "therapy based solely on what this app shows — if anything in the app ever "
              "conflicts with your pump's own display or alarms, trust the pump.",
        ),
        LegalSection(
          'Not affiliated',
          'Pod Tracker is an independent, solo-developed project. It is not affiliated '
              'with, endorsed by, or sponsored by Insulet, Omnipod, or any other pump or '
              'pod manufacturer.',
        ),
        LegalSection(
          'License',
          "Pod Tracker's source code is released under the MIT License — see the LICENSE "
              'file in the project repository. You are free to use, modify, and share it.',
        ),
        LegalSection(
          'Your responsibilities',
          "The app's countdowns, stock estimates, and reminders are only as accurate as "
              "the information you give it and your device's clock. Keep your device's "
              'date and time correct, and keep pod duration, grace period, and stock '
              'counts up to date for the numbers to mean anything.',
        ),
        LegalSection(
          'No warranty',
          'Pod Tracker is provided "as is," without warranty of any kind, express or '
              'implied, including any warranty of accuracy, reliability, or fitness for a '
              'particular purpose.',
        ),
        LegalSection(
          'Limitation of liability',
          'To the maximum extent permitted by law, the developer is not liable for any '
              'damages — including a missed reminder, an inaccurate estimate, or lost data '
              '— arising from your use of, or inability to use, Pod Tracker.',
        ),
        LegalSection(
          'Changes',
          'These terms, and the app itself, may change over time as a solo project. '
              'Continuing to use Pod Tracker after an update means you accept the terms as '
              'they stand at that version.',
        ),
        LegalSection(
          'Contact',
          'Questions about these terms can be raised as a GitHub issue — see Contact '
              'Support in Settings.',
        ),
      ],
    );
  }
}
