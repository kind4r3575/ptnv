import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// The app's tap target: a drop-in for `GestureDetector(onTap: …)` that shows
/// the user their tap registered. While a finger is down the [child] shrinks
/// slightly and fades a little; on release it springs back with a small bounce
/// past full size (100% → 96% … → 102% → 100%). A completed tap also gives a
/// light haptic tick.
///
/// A quick tap — especially in a scrolling list, where the tap only registers
/// once the finger lifts — would otherwise start the press and the action in
/// the same frame, and an action that opens a screen or sheet covers the
/// button before the press is ever seen. So [onTap] runs once the press-in
/// has been on screen (≤ [pressInDuration]); the haptic tick is immediate.
///
/// Every button, row, chip and tile in the app goes through this, so press
/// feedback looks and feels the same everywhere. A null [onTap] means
/// disabled: no animation, no haptic, taps ignored.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.behavior = HitTestBehavior.opaque,
  });

  final VoidCallback? onTap;
  final Widget child;
  final HitTestBehavior behavior;

  /// How long the press-in takes — and so the most a quick tap's action waits.
  static const Duration pressInDuration = Duration(milliseconds: 70);

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  /// Size and opacity at full press depth (depth 1).
  static const double _pressedScale = 0.96;
  static const double _pressedOpacity = 0.7;

  /// Press depth: 0 at rest, 1 fully pressed, below 0 during the release
  /// bounce (bigger than normal size). Unbounded so it can overshoot.
  late final AnimationController _depth = AnimationController.unbounded(vsync: this);
  late final Animation<double> _scale =
      _depth.drive(Tween<double>(begin: 1, end: _pressedScale)); // extrapolates past 1 in the bounce
  late final Animation<double> _opacity = _depth.drive(const _FadeForDepth(_pressedOpacity));

  bool _fingerDown = false;

  /// The press-in currently running, if any.
  TickerFuture? _pressIn;

  bool get _enabled => widget.onTap != null;

  void _onTapDown(TapDownDetails _) {
    _fingerDown = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    final pressIn =
        _depth.animateTo(1, duration: Pressable.pressInDuration, curve: Curves.easeOut);
    _pressIn = pressIn;
    pressIn.whenCompleteOrCancel(() {
      if (identical(_pressIn, pressIn)) _pressIn = null;
    });
  }

  /// Runs [then] once the press-in has finished — right away if it already
  /// has (finger held down) or never started (reduce motion). A new press
  /// interrupting this one still runs it, so rapid taps are never dropped.
  void _afterPressIn(VoidCallback then) {
    final pressIn = _pressIn;
    if (pressIn != null) {
      pressIn.whenCompleteOrCancel(then);
    } else {
      then();
    }
  }

  void _release() {
    if (_depth.value == 0) return; // never pressed in (reduce motion) — nothing to undo
    _depth.animateWith(PressRelease(from: _depth.value));
  }

  void _onTapEnd() {
    _fingerDown = false;
    _afterPressIn(() {
      if (mounted && !_fingerDown) _release();
    });
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    final action = widget.onTap;
    _afterPressIn(() {
      if (mounted) action?.call();
    });
  }

  @override
  void didUpdateWidget(Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _fingerDown) {
      _fingerDown = false;
      _release(); // disabled mid-press — don't stay stuck pressed in
    }
  }

  @override
  void dispose() {
    _depth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: _enabled ? _onTap : null,
      onTapDown: _enabled ? _onTapDown : null,
      onTapUp: _enabled ? (_) => _onTapEnd() : null,
      onTapCancel: _enabled ? _onTapEnd : null,
      child: ScaleTransition(
        scale: _scale,
        child: FadeTransition(opacity: _opacity, child: widget.child),
      ),
    );
  }
}

/// Opacity for a press depth: fades toward [pressed] as the press deepens,
/// and stays fully opaque through the release bounce (depth below 0).
class _FadeForDepth extends Animatable<double> {
  const _FadeForDepth(this.pressed);

  final double pressed;

  @override
  double transform(double depth) => 1 - (1 - pressed) * depth.clamp(0.0, 1.0);
}

/// The release motion for a press depth, shared with `AppSwitch`: from
/// [from] it springs out to [overshoot] (below 0, i.e. bigger than normal
/// size), then settles back at rest — one bounce, no wobble.
class PressRelease extends Simulation {
  PressRelease({required this.from, this.overshoot = -0.5});

  final double from;

  /// Depth at the peak of the bounce. −0.5 with [Pressable]'s 4% press is a
  /// 2% overshoot (102% size).
  final double overshoot;

  static const double _out = 0.07; // seconds to the bounce peak
  static const double _settle = 0.09; // seconds from the peak back to rest

  /// The whole release, start to rest.
  static const Duration duration = Duration(milliseconds: 160);

  @override
  double x(double time) {
    if (time <= 0) return from;
    if (time < _out) {
      return _lerp(from, overshoot, Curves.easeOut.transform(time / _out));
    }
    if (time < _out + _settle) {
      return _lerp(overshoot, 0, Curves.easeInOut.transform((time - _out) / _settle));
    }
    return 0;
  }

  @override
  double dx(double time) {
    const h = 0.001;
    return (x(time + h) - x(time - h)) / (2 * h);
  }

  @override
  bool isDone(double time) => time >= _out + _settle;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// A 48×48 icon button with [Pressable]'s feedback — the app-bar back arrow.
class PressableIconButton extends StatelessWidget {
  const PressableIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.navy,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(child: Icon(icon, color: color, size: 24)),
      ),
    );
  }
}
