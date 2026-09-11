import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'home_parts.dart';

/// A pushed sub-page: back-button app bar over a scrollable body, in the
/// app's standard layout. Used by Help & FAQ, Contact Support, Privacy
/// Policy and Terms of Service.
class SimplePage extends StatelessWidget {
  const SimplePage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBarWave(
              title: title,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                splashRadius: 22,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
