import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

/// The app-wide toggle switch. Track is [AppColors.cyan] (#86BBD8) when on and
/// the same cyan at 55% opacity when off; the thumb is always white and the
/// default grey outline is removed. Used everywhere a [Switch] would be.
///
/// Matches [Pressable]'s feedback: each toggle gives a light haptic tick and a
/// quick press "pulse" (shrink, then spring back with a small bounce past full
/// size — see [PressRelease]). It's driven by the toggle
/// itself rather than a wrapping tap detector, so it never fights the
/// switch's own tap and drag handling, and a scroll starting on the switch
/// doesn't trigger it.
class AppSwitch extends StatefulWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<AppSwitch> createState() => _AppSwitchState();
}

class _AppSwitchState extends State<AppSwitch> with SingleTickerProviderStateMixin {
  /// Deeper than [Pressable]'s 0.96 — on a control this small, 4% is ~1px.
  static const double _pulseScale = 0.88;

  /// Bounce peak: −0.25 of a 12% dip is a 3% overshoot (103% size).
  static const double _overshoot = -0.25;

  /// Press depth, as in [Pressable]: 0 at rest, 1 at the bottom of the
  /// pulse, below 0 during the bounce.
  late final AnimationController _depth = AnimationController.unbounded(vsync: this);
  late final Animation<double> _scale =
      _depth.drive(Tween<double>(begin: 1, end: _pulseScale)); // extrapolates in the bounce

  /// Bumped per toggle, so a pulse interrupted by the next toggle doesn't
  /// spring back in the middle of the new one.
  int _pulseId = 0;

  void _onChanged(bool value) {
    HapticFeedback.lightImpact();
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      final id = ++_pulseId;
      _depth
          .animateTo(1, duration: Pressable.pressInDuration, curve: Curves.easeOut)
          .whenCompleteOrCancel(() {
        if (mounted && id == _pulseId) {
          _depth.animateWith(PressRelease(from: _depth.value, overshoot: _overshoot));
        }
      });
    }
    widget.onChanged(value);
  }

  @override
  void dispose() {
    _depth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Switch(
        value: widget.value,
        onChanged: _onChanged,
        thumbColor: const WidgetStatePropertyAll(AppColors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.cyan
              : AppColors.cyan.withValues(alpha: 0.55),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
