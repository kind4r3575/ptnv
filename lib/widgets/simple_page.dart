import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'home_parts.dart';
import 'pressable.dart';

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
              leading: PressableIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
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
