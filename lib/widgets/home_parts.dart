import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../state/root_tabs.dart';
import '../theme/tokens.dart';

// ===========================================================================
// Top app bar — "Pod Tracker" wordmark + decorative wave.
// ===========================================================================

class AppBarWave extends StatelessWidget {
  const AppBarWave({
    super.key,
    this.title = 'Pod Tracker',
    this.leading,
  });

  final String title;

  /// Optional leading widget (e.g. a back button on secondary screens).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(width: leading == null ? 16 : 6),
          ?leading,
          Text(title, style: AppText.appTitle),
          const SizedBox(width: 8),
          Expanded(
            child: CustomPaint(
              painter: _WavePainter(),
              size: const Size.fromHeight(56),
            ),
          ),
        ],
      ),
    );
  }
}

/// The standard [AppBarWave] back arrow, for a screen that may or may not be
/// sitting on a pushed route.
///
/// Stock, History and Settings double as `RootShell`'s `IndexedStack` tabs,
/// where this is the *only* route on the navigator: popping would leave the
/// navigator empty and paint a black screen, so there it switches to the Home
/// tab instead. An instance that really was pushed (Stock again, from Home's
/// stock info row) pops as usual.
Widget appBackButton(BuildContext context, RootTabController tabs) => IconButton(
      onPressed: () {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          tabs.goTo(0);
        }
      },
      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
      splashRadius: 22,
    );

class _WavePainter extends CustomPainter {
  // amplitude, phase, frequency
  static final List<List<double>> _waves = [
    [16, 0.0, 1.6],
    [12, 0.7, 1.3],
    [9, 1.4, 1.9],
    [6, 2.1, 2.2],
  ];
  static final List<Color> _colors = [
    AppColors.navy.withValues(alpha: 0.55),
    AppColors.blue.withValues(alpha: 0.45),
    AppColors.cyan.withValues(alpha: 0.75),
    AppColors.cyan.withValues(alpha: 0.40),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    for (var i = 0; i < _waves.length; i++) {
      final amp = _waves[i][0];
      final phase = _waves[i][1];
      final freq = _waves[i][2];
      final paint = Paint()
        ..color = _colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (double x = 0; x <= size.width; x += 4) {
        final t = x / size.width;
        final y = midY + amp * math.sin(t * freq * 2 * math.pi + phase);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===========================================================================
// Bottom navigation bar — labelled icons; the selected tab pops up over the
// bar's top edge.
// ===========================================================================

/// Every bottom-tab screen owns its own [HomeBottomBar] (they all stay
/// mounted in `RootShell`'s `IndexedStack`), so the bar that was tapped is
/// hidden the moment the tab switches. The *destination* bar therefore plays
/// the transition: it listens to [tabs] and, when its own tab becomes
/// current, animates that tab jumping up while the one just left settles
/// back down — picking up where the tapped bar's picture left off.
class HomeBottomBar extends StatefulWidget {
  const HomeBottomBar({
    super.key,
    this.selectedIndex = 0,
    this.tabs,
    this.onInactiveTap,
    this.onAddTap,
    this.onHomeTap,
    this.onStockTap,
    this.onHistoryTap,
    this.onSettingsTap,
  });

  /// The bar's height above the system's bottom inset: 64px items plus 12px
  /// padding above and below. Popups opened from the bar float just above it.
  static const double height = _itemExtent + 2 * _verticalPadding;
  static const double _itemExtent = 64;
  static const double _verticalPadding = 12;

  /// Which tab is highlighted: 0 = Home, 1 = Stock, 3 = History, 4 = Settings.
  final int selectedIndex;

  /// The shared tab state. When it switches to [selectedIndex] this bar plays
  /// the jump animation; without it the selected tab simply sits raised.
  final RootTabController? tabs;

  final VoidCallback? onInactiveTap;

  /// Tapping the center `+` opens the "Start New Pod" sheet. The `+` stays
  /// raised until the returned future completes, i.e. the sheet closes.
  final Future<void> Function()? onAddTap;

  /// Tapping the Home / Stock / History / Settings tabs (when not selected).
  final VoidCallback? onHomeTap;
  final VoidCallback? onStockTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onSettingsTap;

  @override
  State<HomeBottomBar> createState() => _HomeBottomBarState();
}

class _HomeBottomBarState extends State<HomeBottomBar> with TickerProviderStateMixin {
  /// How far the selected tab rises — enough for its highlight box to poke
  /// about 4px out over the bar's top edge.
  static const double _lift = 16;

  /// Every motion in the bar is one short, soft ease-in-out slide. The curve
  /// is symmetric, so settling back (or reversing mid-way) looks the same.
  static const Duration _duration = Duration(milliseconds: 250);
  static const Curve _curve = Curves.easeInOut;

  /// The tab whose bar was just tapped, i.e. the one showing raised. Set only
  /// while the tap callback runs (it switches tabs synchronously), so the
  /// destination bar settles *that* tab back down. It can differ from the old
  /// [RootTabController.index]: Stock pushed from Home's stock row shows
  /// Stock raised while the index is still Home.
  static int? _tappedFrom;

  /// 0 → 1 as the selected tab rises (and the previous one settles).
  late final AnimationController _raise;

  /// 0 → 1 as the center `+` rises when tapped. It stays up while the Start
  /// New Pod popup is open and settles back down once the popup closes.
  late final AnimationController _addRaise;

  late final Listenable _animation;

  /// The tab settling back down while [_raise] runs.
  int? _previousIndex;

  /// Last seen [RootTabController.index], to know which tab we came from.
  late int _lastTabIndex;

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    // Starts finished: a bar shown for the first time has its tab already
    // raised, without a jump.
    _raise = AnimationController(vsync: this, duration: _duration, value: 1);
    _addRaise = AnimationController(vsync: this, duration: _duration);
    _animation = Listenable.merge([_raise, _addRaise]);
    _lastTabIndex = widget.tabs?.index ?? widget.selectedIndex;
    widget.tabs?.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(HomeBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs != widget.tabs) {
      oldWidget.tabs?.removeListener(_onTabChanged);
      widget.tabs?.addListener(_onTabChanged);
      _lastTabIndex = widget.tabs?.index ?? widget.selectedIndex;
    }
  }

  @override
  void dispose() {
    widget.tabs?.removeListener(_onTabChanged);
    _raise.dispose();
    _addRaise.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final now = widget.tabs!.index;
    final before = _lastTabIndex;
    _lastTabIndex = now;
    if (now != widget.selectedIndex || now == before) return;
    setState(() => _previousIndex = _tappedFrom ?? before);
    if (_reduceMotion) {
      _raise.value = 1;
    } else {
      _raise.forward(from: 0);
    }
  }

  void _onTabTap(VoidCallback onTap) {
    _tappedFrom = widget.selectedIndex;
    onTap();
    _tappedFrom = null;
  }

  /// Raises the `+` while its popup is open, then settles it back down.
  Future<void> _onAddTap() async {
    final onAddTap = widget.onAddTap;
    if (onAddTap == null) {
      widget.onInactiveTap?.call();
      return;
    }
    _setAddRaised(true);
    try {
      await onAddTap();
    } finally {
      if (mounted) _setAddRaised(false);
    }
  }

  void _setAddRaised(bool raised) {
    if (_reduceMotion) {
      _addRaise.value = raised ? 1 : 0;
    } else if (raised) {
      _addRaise.forward();
    } else {
      _addRaise.reverse();
    }
  }

  /// One nav item: icon over label in a 64×64 box. [raised] (0 → 1) slides it
  /// up and fades in the cyan selected box and its shadow.
  Widget _item({
    required IconData icon,
    required String label,
    double iconSize = 28,
    double raised = 0,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Transform.translate(
        offset: Offset(0, -_lift * raised),
        child: Container(
          width: HomeBottomBar._itemExtent,
          height: HomeBottomBar._itemExtent,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.cyan.withValues(alpha: 0.55 * raised),
            borderRadius: BorderRadius.circular(18),
            boxShadow: raised == 0
                ? null
                : [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.18 * raised),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: AppColors.navy),
              const SizedBox(height: 2),
              // Shrinks rather than overflows at large text sizes.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: AppText.navLabel, maxLines: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int index, IconData icon, String label, VoidCallback? onTap) {
    final t = _curve.transform(_raise.value);
    final selected = index == widget.selectedIndex;
    // The selected tab rises and stays up; the one just left settles back.
    final raised = selected ? t : (index == _previousIndex ? 1 - t : 0.0);
    final tap = onTap ?? widget.onInactiveTap;
    return _item(
      icon: icon,
      label: label,
      raised: raised,
      onTap: selected || tap == null ? null : () => _onTabTap(tap),
    );
  }

  Widget _addButton() {
    return _item(
      icon: Icons.add_rounded,
      label: 'Add',
      iconSize: 32,
      // Rises and lights up like a selected tab while its popup is open.
      raised: _curve.transform(_addRaise.value),
      onTap: _onAddTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cyanBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: HomeBottomBar._verticalPadding,
          ),
          // Only the row of items rebuilds on each animation frame.
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _tab(0, Icons.home_rounded, 'Home', widget.onHomeTap),
                _tab(1, Icons.inventory_2_outlined, 'Stock', widget.onStockTap),
                _addButton(),
                _tab(3, Icons.history_rounded, 'History', widget.onHistoryTap),
                _tab(4, Icons.settings_outlined, 'Settings', widget.onSettingsTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Countdown card — one widget renders On-track / Grace / Late.
// ===========================================================================

class CountdownCard extends StatelessWidget {
  const CountdownCard({super.key, required this.session, this.onEditStart});

  final PodSession session;

  /// Opens the pod's start date/time editor. Wired to both the big headline
  /// stamp and the STARTED box: the headline is where the eye goes, but it's
  /// [PodSession.startedAt] that is editable — the end, grace end and
  /// countdown are all derived from it. Null leaves the card read-only.
  final VoidCallback? onEditStart;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = session.statusAt(now);
    final style = _StatusStyle.of(status);
    final headline = status == TrackedItemStatus.onTrack ? session.endAt : session.graceEndAt;

    final secondValue = status == TrackedItemStatus.onTrack
        ? fmtAuto(session.elapsed(now))
        : fmtHm(session.worn(now));

    final String thirdValue;
    final String leftCaption;
    final String rightCaption;
    switch (status) {
      case TrackedItemStatus.onTrack:
        thirdValue = fmtHm(session.remaining(now));
        leftCaption = 'Passed ${fmtAuto(session.elapsed(now))}';
        rightCaption = '${fmtHm(session.remaining(now))} left';
      case TrackedItemStatus.grace:
        thirdValue = fmtHm(session.graceLeft(now));
        leftCaption = 'Worn ${fmtHm(session.worn(now))}';
        rightCaption = '${fmtHm(session.graceLeft(now))} grace left';
      case TrackedItemStatus.late:
        thirdValue = '+${fmtHm(session.overdue(now))}';
        leftCaption = 'Worn ${fmtHm(session.worn(now))}';
        rightCaption = 'Stopped ${fmtHm(session.overdue(now))} ago';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(style.topLabel, style: AppText.eyebrow),
              _Badge(text: style.badgeText, bg: style.badgeBg, fg: style.badgeFg),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onEditStart,
            // Opaque only when there's something to tap, so a read-only card
            // doesn't swallow gestures over the middle of itself.
            behavior: onEditStart == null
                ? HitTestBehavior.deferToChild
                : HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Text(fmtFullDate(headline), style: AppText.cardDate)),
                const SizedBox(height: 4),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(fmtClock(headline), style: AppText.bigTime),
                  ),
                ),
                const SizedBox(height: 2),
                Center(child: Text(style.subtitle, style: AppText.caption)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: style.accent, shape: BoxShape.circle),
              ),
              Text(style.statusText,
                  style: AppText.statusLabel.copyWith(color: style.accent)),
            ],
          ),
          const SizedBox(height: 12),
          _ProgressBar(fraction: session.progress(now), color: style.accent),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(leftCaption, style: AppText.caption),
              Text(rightCaption, style: AppText.caption),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'STARTED',
                  value: fmtShortStamp(session.startedAt),
                  onTap: onEditStart,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(label: style.secondLabel, value: secondValue)),
            ],
          ),
          const SizedBox(height: 10),
          _StatBox(label: style.thirdLabel, value: thirdValue, valueColor: style.accent),
        ],
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.accent,
    required this.badgeBg,
    required this.badgeFg,
    required this.badgeText,
    required this.topLabel,
    required this.statusText,
    required this.subtitle,
    required this.secondLabel,
    required this.thirdLabel,
  });

  final Color accent;
  final Color badgeBg;
  final Color badgeFg;
  final String badgeText;
  final String topLabel;
  final String statusText;
  final String subtitle;
  final String secondLabel;
  final String thirdLabel;

  static _StatusStyle of(TrackedItemStatus status) {
    switch (status) {
      case TrackedItemStatus.onTrack:
        return const _StatusStyle(
          accent: AppColors.green,
          badgeBg: AppColors.green,
          badgeFg: Colors.white,
          badgeText: 'Within 72 hours',
          topLabel: 'ENDS ON',
          statusText: 'ON TRACK',
          subtitle: 'end date & time',
          secondLabel: 'PASSED',
          thirdLabel: 'REMAINING',
        );
      case TrackedItemStatus.grace:
        return const _StatusStyle(
          accent: AppColors.amberText,
          badgeBg: AppColors.amberBg,
          badgeFg: AppColors.amberText,
          badgeText: 'Grace period',
          topLabel: 'GRACE ENDS',
          statusText: 'GRACE',
          subtitle: 'still delivering · change before this',
          secondLabel: 'WORN',
          thirdLabel: 'GRACE LEFT',
        );
      case TrackedItemStatus.late:
        return const _StatusStyle(
          accent: AppColors.redText,
          badgeBg: AppColors.redBg,
          badgeFg: AppColors.redText,
          badgeText: 'Change needed',
          topLabel: 'GRACE ENDED',
          statusText: 'NOT DELIVERING',
          subtitle: 'pod stopped delivering',
          secondLabel: 'WORN',
          thirdLabel: 'OVERDUE',
        );
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: AppText.badge.copyWith(color: fg)),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// When set, the box is tappable and its label carries a pencil, so the one
  /// editable stat on the card reads as editable instead of looking identical
  /// to the computed ones beside it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cyanBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(label, style: AppText.statLabel),
              if (onTap != null) ...[
                const SizedBox(width: 5),
                const Icon(Icons.edit_rounded, size: 12, color: AppColors.slate),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: AppText.statValue.copyWith(color: valueColor ?? AppColors.navy)),
        ],
      ),
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final fillW = fraction <= 0 ? 0.0 : (w * fraction).clamp(8.0, w);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Container(
                width: fillW,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Primary action button.
// ===========================================================================

class EndPodButton extends StatelessWidget {
  const EndPodButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 160,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Text('End Pod', style: AppText.button),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Info rows (Stock / Predicted Run-out / Next Reminder).
// ===========================================================================

class HomeInfoRows extends StatelessWidget {
  const HomeInfoRows({
    super.key,
    required this.stock,
    required this.predictedRunOut,
    required this.reminderText,
    this.onReminderTap,
    this.onStockTap,
  });

  final int stock;
  final DateTime predictedRunOut;
  final String reminderText;

  /// Opens the Notifications editor from the "Next Reminder" row (Figma 66-431).
  final VoidCallback? onReminderTap;

  /// Opens the Stock screen from the "Stock" row.
  final VoidCallback? onStockTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoRow(
          icon: Icons.inventory_2_outlined,
          title: 'Stock',
          value: '$stock pods',
          onTap: onStockTap,
        ),
        const SizedBox(height: 14),
        _InfoRow(
          icon: Icons.event_rounded,
          title: 'Predicted Run-out',
          value: fmtDate(predictedRunOut),
        ),
        const SizedBox(height: 14),
        _InfoRow(
          icon: Icons.notifications_active_rounded,
          title: 'Next Reminder',
          value: reminderText,
          onTap: onReminderTap,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.value, this.onTap});

  final IconData icon;
  final String title;
  final String value;

  /// When set, the row is tappable and shows a trailing chevron.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cyanBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.navy, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.rowTitle),
                  const SizedBox(height: 2),
                  Text(value, style: AppText.rowValue),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate, size: 22),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Empty state — no active pod.
// ===========================================================================

class NoActivePodView extends StatelessWidget {
  const NoActivePodView({super.key, required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medical_services_outlined, size: 76, color: AppColors.navy),
          const SizedBox(height: 20),
          Text('No Active Pod', style: AppText.emptyTitle),
          const SizedBox(height: 8),
          Text('Start a new pod session', style: AppText.emptySub),
          const SizedBox(height: 20),
          Text('Pods in Stock: $stock', style: AppText.rowValue),
        ],
      ),
    );
  }
}

// ===========================================================================
// Loading skeleton (pulse shimmer of placeholder blocks).
// ===========================================================================

class HomeSkeleton extends StatefulWidget {
  const HomeSkeleton({super.key});

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _pulse =
      Tween<double>(begin: 0.45, end: 0.9).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  static const Color _grey = Color(0xFFDDE5EC);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _grey,
          borderRadius: BorderRadius.circular(8),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Opacity(opacity: _pulse.value, child: child),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 36),
            Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(color: _grey, shape: BoxShape.circle),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _bar(90, 14),
                    const SizedBox(height: 10),
                    _bar(60, 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            _bar(220, 14),
            const SizedBox(height: 10),
            _bar(140, 12),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(150, 12),
                  const SizedBox(height: 12),
                  _bar(double.infinity, 12),
                  const SizedBox(height: 12),
                  _bar(110, 12),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _bar(double.infinity, 60),
          ],
        ),
      ),
    );
  }
}
