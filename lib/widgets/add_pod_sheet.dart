import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../theme/tokens.dart';
import 'sheet_parts.dart';
import 'start_time_picker_sheet.dart';

/// Slides the "Start New Pod" sheet up over a scrim. Mirrors Figma node
/// `164:65` — pick an insertion site and start a pod from the bottom bar's `+`.
Future<void> showAddPodSheet(BuildContext context, PodController controller) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.navy.withValues(alpha: 0.45),
    builder: (_) => AddPodSheet(controller: controller),
  );
}

/// The floating "Start New Pod" modal card.
///
/// Insertion-site selection drives the chip highlight only (not persisted yet).
/// "Now" starts the pod at the current time; "Custom" opens a date/time picker.
class AddPodSheet extends StatefulWidget {
  const AddPodSheet({super.key, required this.controller});

  final PodController controller;

  @override
  State<AddPodSheet> createState() => _AddPodSheetState();
}

class _AddPodSheetState extends State<AddPodSheet> {
  static const List<String> _sites = [
    'Abdomen', 'Lower back', 'Left arm', 'Right arm', 'Left thigh', 'Right thigh',
  ];

  String _selectedSite = 'Abdomen';
  bool _useNow = true;
  DateTime? _customStart; // set once a custom time is chosen

  /// The start time the pod would begin at, given the current selection.
  DateTime get _start => _useNow || _customStart == null ? DateTime.now() : _customStart!;

  Future<void> _openCustom() async {
    final picked = await showStartTimePicker(
      context,
      initial: _start,
      footnote: (d) => 'Pod will expire '
          '${fmtExpiry(d.add(const Duration(hours: PodSession.durationHours)))}',
    );
    if (picked != null && mounted) {
      setState(() {
        _useNow = false;
        _customStart = picked;
      });
    }
  }

  void _startPod() {
    widget.controller.startPod(
      startedAt: _useNow ? null : _customStart,
      site: _selectedSite,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // "Now" → current time; "Custom" → the chosen time. Pod is rated for 72h.
    final start = _start;
    final expiry = start.add(const Duration(hours: PodSession.durationHours));

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
                const SizedBox(height: 24),
                Text('INSERTION SITE', style: AppText.eyebrow),
                const SizedBox(height: 12),
                ChipGrid(
                  labels: _sites,
                  selected: _selectedSite,
                  onSelected: (s) => setState(() => _selectedSite = s),
                ),
                const SizedBox(height: 20),
                Text('START TIME', style: AppText.eyebrow),
                const SizedBox(height: 10),
                SegmentedToggle(
                  leftLabel: 'Now',
                  rightLabel: 'Custom',
                  leftSelected: _useNow,
                  onLeft: () => setState(() => _useNow = true),
                  onRight: _openCustom,
                ),
                const SizedBox(height: 10),
                Text(fmtStartsAt(start), style: AppText.caption),
                const SizedBox(height: 14),
                _expiresCard(expiry),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '${widget.controller.stock} pods in stock — 1 will be used',
                    style: AppText.caption,
                  ),
                ),
                const SizedBox(height: 16),
                _startButton(),
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
              Text('Start New Pod', style: AppText.sheetTitle),
              const SizedBox(height: 4),
              Text('Set up your next pod session', style: AppText.sheetSubtitle),
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

  Widget _expiresCard(DateTime expiry) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cyanBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('POD EXPIRES', style: AppText.statLabel),
              const SizedBox(height: 2),
              Text(fmtExpiry(expiry), style: AppText.statValue),
            ],
          ),
          const Spacer(),
          Text(
            '${PodSession.durationHours}h',
            style: AppText.sheetTitle.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _startButton() {
    return GestureDetector(
      onTap: _startPod,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: 0.35),
              blurRadius: 9,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text('Start Pod', style: AppText.button.copyWith(fontSize: 16)),
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

