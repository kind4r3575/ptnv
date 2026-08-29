import 'package:flutter/material.dart';

/// Shared fast fade transition for pushed screens, used in place of the
/// default [MaterialPageRoute] (300ms) so every push in the app feels as
/// snappy as the bottom-tab switch.
Route<T> fadePushRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
    );
