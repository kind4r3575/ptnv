import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The app-wide toggle switch. Track is [AppColors.cyan] (#86BBD8) when on and
/// the same cyan at 55% opacity when off; the thumb is always white and the
/// default grey outline is removed. Used everywhere a [Switch] would be.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: const WidgetStatePropertyAll(AppColors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.cyan
            : AppColors.cyan.withValues(alpha: 0.55),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}
