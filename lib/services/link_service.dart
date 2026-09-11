import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';

/// Opens destinations outside the app (GitHub, the platform store listing).
///
/// Pod Tracker itself never makes a network call — every one of these hands
/// off to another app (browser, Play Store, App Store) that does, which is
/// why the Android build has no `INTERNET` permission of its own.
class LinkService {
  LinkService._();

  static Future<void> openGitHubIssues(BuildContext context) =>
      _open(context, Uri.parse(AppConfig.githubIssuesUrl));

  static Future<void> openGitHubRepo(BuildContext context) =>
      _open(context, Uri.parse(AppConfig.githubRepoUrl));

  /// "Rate the App" — resolves the right store URL for the current platform
  /// at call time, so once [AppConfig.isPublished] is flipped this needs no
  /// further code changes.
  static Future<void> openStoreListing(BuildContext context) async {
    if (Platform.isIOS) {
      final id = AppConfig.appStoreId;
      if (id == null) {
        _toast(context, 'Not available yet.');
        return;
      }
      await _open(context, Uri.parse('https://apps.apple.com/app/id$id'));
      return;
    }
    if (Platform.isAndroid) {
      final info = await PackageInfo.fromPlatform();
      final marketUri = Uri.parse('market://details?id=${info.packageName}');
      final webUri =
          Uri.parse('https://play.google.com/store/apps/details?id=${info.packageName}');
      final canUseStoreApp = await canLaunchUrl(marketUri);
      if (!context.mounted) return;
      await _open(context, canUseStoreApp ? marketUri : webUri,
          failureMessage: "Couldn't open the Play Store.");
      return;
    }
    _toast(context, 'Not available on this platform.');
  }

  static Future<void> _open(
    BuildContext context,
    Uri uri, {
    String? failureMessage,
  }) async {
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      _toast(context, failureMessage ?? "Couldn't open that link.");
    }
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }
}
