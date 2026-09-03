import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/pod.dart';
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
// Bottom navigation bar (Home selected; other tabs inert for now).
// ===========================================================================

class HomeBottomBar extends StatelessWidget {
  const HomeBottomBar({
    super.key,
    this.selectedIndex = 0,
    this.onInactiveTap,
    this.onAddTap,
    this.onHomeTap,
    this.onStockTap,
    this.onHistoryTap,
    this.onSettingsTap,
  });

  /// Which tab is highlighted: 0 = Home, 1 = Stock, 3 = History, 4 = Settings.
  final int selectedIndex;

  final VoidCallback? onInactiveTap;

  /// Tapping the center `+` opens the "Start New Pod" sheet.
  final VoidCallback? onAddTap;

  /// Tapping the Home / Stock / History / Settings tabs (when not selected).
  final VoidCallback? onHomeTap;
  final VoidCallback? onStockTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onSettingsTap;

  Widget _item(IconData icon, {bool selected = false, double size = 28, VoidCallback? onTap}) {
    if (selected) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.cyan.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, size: 30, color: AppColors.navy),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? onInactiveTap,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Icon(icon, size: size, color: AppColors.navy),
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _item(Icons.home_rounded, selected: selectedIndex == 0, onTap: onHomeTap),
              _item(Icons.inventory_2_outlined, selected: selectedIndex == 1, onTap: onStockTap),
              _item(Icons.add_rounded, size: 32, onTap: onAddTap),
              _item(Icons.history_rounded, selected: selectedIndex == 3, onTap: onHistoryTap),
              _item(Icons.settings_outlined, selected: selectedIndex == 4, onTap: onSettingsTap),
            ],
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
  const CountdownCard({super.key, required this.session});

  final PodSession session;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = session.statusAt(now);
    final style = _StatusStyle.of(status);
    final headline = status == PodStatus.onTrack ? session.endAt : session.graceEndAt;

    final secondValue = status == PodStatus.onTrack
        ? fmtAuto(session.elapsed(now))
        : fmtHm(session.worn(now));

    final String thirdValue;
    final String leftCaption;
    final String rightCaption;
    switch (status) {
      case PodStatus.onTrack:
        thirdValue = fmtHm(session.remaining(now));
        leftCaption = 'Passed ${fmtAuto(session.elapsed(now))}';
        rightCaption = '${fmtHm(session.remaining(now))} left';
      case PodStatus.grace:
        thirdValue = fmtHm(session.graceLeft(now));
        leftCaption = 'Worn ${fmtHm(session.worn(now))}';
        rightCaption = '${fmtHm(session.graceLeft(now))} grace left';
      case PodStatus.late:
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
              Expanded(child: _StatBox(label: 'STARTED', value: fmtShortStamp(session.startedAt))),
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

  static _StatusStyle of(PodStatus status) {
    switch (status) {
      case PodStatus.onTrack:
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
      case PodStatus.grace:
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
      case PodStatus.late:
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
  const _StatBox({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cyanBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.statLabel),
          const SizedBox(height: 4),
          Text(value, style: AppText.statValue.copyWith(color: valueColor ?? AppColors.navy)),
        ],
      ),
    );
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
