import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../theme/tokens.dart';
import 'sheet_parts.dart';
import 'start_time_picker_sheet.dart';

/// Slides the "End Pod Session" confirmation sheet up over a scrim. Mirrors
/// Figma node `168:101` — confirm before closing the active pod.
Future<void> showEndPodSheet(BuildContext context, PodController controller) {
  if (controller.session == null) return Future<void>.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.navy.withValues(alpha: 0.45),
    builder: (_) => EndPodSheet(controller: controller),
  );
}

/// The floating "End Pod Session" modal card.
///
/// Reason + end time drive the sheet UI only (not persisted yet, like Add Pod's
/// site/time). "Now" ends at the current time; "Custom" reuses the shared
/// start-time picker with "End time" wording.
class EndPodSheet extends StatefulWidget {
  const EndPodSheet({super.key, required this.controller});

  final PodController controller;

  @override
  State<EndPodSheet> createState() => _EndPodSheetState();
}

class _EndPodSheetState extends State<EndPodSheet> {
  static const List<String> _reasons = [
    'Planned', 'Blockage', 'Irritation', 'Leak', 'Ran low', 'Other',
  ];

  String _reason = 'Planned';
  bool _useNow = true;
  DateTime? _customEnd;

  PodSession get _session => widget.controller.session!;

  /// The end time given the current selection.
  DateTime get _end => _useNow || _customEnd == null ? DateTime.now() : _customEnd!;

  Future<void> _openCustom() async {
    final start = _session.startedAt;
    final picked = await showStartTimePicker(
      context,
      initial: _end,
      title: 'End time',
      subtitle: 'When did you change this pod?',
      confirmLabel: 'Set end time',
      footnote: (d) {
        final worn = d.isAfter(start) ? d.difference(start) : Duration.zero;
        return 'Worn ${fmtHm(worn)} at this time';
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _useNow = false;
        _customEnd = picked;
      });
    }
  }

  void _endPod() {
    widget.controller.endPod(
      endedAt: _useNow ? null : _customEnd,
      reason: _reason,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final now = DateTime.now();

    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
        top: 14,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCD9E5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _header(),
                const SizedBox(height: 20),
                _wornCard(session, now),
                const SizedBox(height: 12),
                Center(child: Text(_limitText(session, now), style: AppText.caption)),
                const SizedBox(height: 16),
                Text('REASON FOR CHANGE', style: AppText.eyebrow),
                const SizedBox(height: 12),
                ChipGrid(
                  labels: _reasons,
                  selected: _reason,
                  onSelected: (r) => setState(() => _reason = r),
                ),
                const SizedBox(height: 18),
                Text('END TIME', style: AppText.eyebrow),
                const SizedBox(height: 10),
                SegmentedToggle(
                  leftLabel: 'Now',
                  rightLabel: 'Custom',
                  leftSelected: _useNow,
                  onLeft: () => setState(() => _useNow = true),
                  onRight: _openCustom,
                ),
                const SizedBox(height: 10),
                Center(child: Text(fmtEndsAt(_end), style: AppText.caption)),
                const SizedBox(height: 16),
                _endButton(),
                const SizedBox(height: 6),
                _cancelButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('End Pod Session', style: AppText.sheetTitle),
              const SizedBox(height: 4),
              Text('This will close your current pod', style: AppText.sheetSubtitle),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate),
          ),
        ),
      ],
    );
  }

  Widget _wornCard(PodSession session, DateTime now) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WORN SO FAR', style: AppText.statLabel),
                    const SizedBox(height: 2),
                    Text(fmtHm(session.worn(now)),
                        style: AppText.sheetTitle.copyWith(fontSize: 18)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('PLANNED', style: AppText.statLabel),
                  const SizedBox(height: 2),
                  Text('${PodSession.durationHours}h',
                      style: AppText.statValue.copyWith(fontSize: 16, color: AppColors.slate)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WornBar(fraction: session.progress(now)),
        ],
      ),
    );
  }

  String _limitText(PodSession session, DateTime now) {
    switch (session.statusAt(now)) {
      case PodStatus.onTrack:
        return '${fmtHm(session.remaining(now))} left until the 72h limit';
      case PodStatus.grace:
        return '${fmtHm(session.graceLeft(now))} of grace left';
      case PodStatus.late:
        return 'Pod stopped delivering ${fmtHm(session.overdue(now))} ago';
    }
  }

  Widget _endButton() {
    return GestureDetector(
      onTap: _endPod,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.endRed,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.endRed.withValues(alpha: 0.35),
              blurRadius: 9,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text('End Pod', style: AppText.button.copyWith(fontSize: 16)),
      ),
    );
  }

  Widget _cancelButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Text(
          'Cancel',
          style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// The thin worn-so-far progress bar in the End Pod card.
class _WornBar extends StatelessWidget {
  const _WornBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final fillW = fraction <= 0 ? 0.0 : (w * fraction).clamp(6.0, w);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.progressTrack,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                width: fillW,
                decoration: BoxDecoration(
                  color: AppColors.progressFill,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
