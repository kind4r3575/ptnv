import 'package:flutter/material.dart';

import '../widgets/legal_doc.dart';

/// Privacy Policy (Settings → About & Support). Content mirrors what's
/// actually true of the build: no `INTERNET` permission on Android, no
/// accounts, no analytics — everything stays in local device storage.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocPage(
      title: 'Privacy Policy',
      lastUpdated: 'September 11, 2026',
      intro: 'Pod Tracker is built to work fully offline, and this policy is short '
          "because there just isn't much to say: the app doesn't collect your data, "
          'because it has no way to send it anywhere.',
      sections: [
        LegalSection(
          'Information we collect',
          'None. Pod Tracker does not collect, transmit, sell, or have access to any of '
              'your personal or health data. There are no user accounts, no analytics SDKs, '
              'no crash-reporting services, and no advertising of any kind.',
        ),
        LegalSection(
          'How your data is stored',
          'Everything you enter — pod type and duration, stock counts, session history, '
              'notification rules, and display settings — is stored only on this device, '
              "using local app storage. None of it is uploaded to a server, because Pod "
              "Tracker doesn't have one.",
        ),
        LegalSection(
          'Network access',
          "The Android build of Pod Tracker does not request the INTERNET permission, so "
              "the app itself is not capable of making a network request. A couple of "
              "settings rows — Contact Support and Rate the App — open your device's "
              "browser or app store when you tap them; those are separate apps, outside "
              "Pod Tracker's control.",
        ),
        LegalSection(
          'Notifications',
          "Reminders you configure — pod expiry, grace period, low stock, and the rest — "
              "are scheduled locally through your device's own notification system. They "
              "are never routed through a push-notification server.",
        ),
        LegalSection(
          'Sharing with third parties',
          "There's nothing to share, because nothing leaves your device. Pod Tracker "
              "doesn't work with ad networks, analytics vendors, or data brokers, and has "
              "none to disclose your data to.",
        ),
        LegalSection(
          'Exporting your history',
          '"Export history as CSV/PDF" builds a file on your device and hands it to your '
              "device's own share sheet. Where that file goes next — email, a clinician's "
              'portal, cloud storage — is entirely your choice, and happens outside the app.',
        ),
        LegalSection(
          'Deleting your data',
          'Uninstalling Pod Tracker deletes everything it stored. "Clear History" and '
              '"Reset to Defaults," in Settings, remove data immediately without '
              'uninstalling.',
        ),
        LegalSection(
          "Children's privacy",
          'Pod Tracker does not knowingly collect information from anyone, including '
              'children, for the simple reason that it does not collect information from '
              'anyone.',
        ),
        LegalSection(
          'Changes to this policy',
          'If this policy ever changes, the update will ship with a new app version and '
              'the date at the top of this page will change with it.',
        ),
        LegalSection(
          'Contact',
          'Questions about this policy can be raised as a GitHub issue on the Pod Tracker '
              'repository — see Contact Support in Settings.',
        ),
      ],
    );
  }
}
