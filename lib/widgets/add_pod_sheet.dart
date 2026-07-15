import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../theme/tokens.dart';
import 'confirm_dialog.dart';
import 'sheet_parts.dart';
import 'start_time_picker_sheet.dart';

/// Slides the "Start New Pod" sheet up over a scrim. Mirrors Figma node
/// `164:65` — pick an insertion site and start a pod from the bottom bar's `+`.
/// Resolves to `'stock'` if the user tapped "Go to Stock" (out of stock), so
/// the caller can switch to the Stock tab; otherwise `null`.
Future<String?> showAddPodSheet(BuildContext context, PodController controller) {
  return showModalBottomSheet<String>(
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
    'Abdomen', 'Left arm', 'Right arm', 'Lower back', 'Left thigh', 'Right thigh',
  ];

  String? _selectedSite; // null until the user picks a site — required to start
  bool _useNow = true;
  DateTime? _customStart; // set once a custom time is chosen

  /// The start time the pod would begin at, given the current selection.
  DateTime get _start => _useNow || _customStart == null ? DateTime.now() : _customStart!;

  Future<void> _openCustom() async {
    final picked = await showStartTimePicker(
      context,
      initial: _start,
      footnote: (d) => 'Pod will expire '
          '${fmtExpiry(d.add(Duration(hours: widget.controller.defaultPodDurationHours)))}',
    );
    if (picked != null && mounted) {
      setState(() {
        _useNow = false;
        _customStart = picked;
      });
    }
  }

  Future<void> _startPod() async {
    if (_selectedSite == null) return; // must pick an insertion site first
    if (widget.controller.stock <= 0) return; // guarded by UI; belt-and-braces

    // A pod is already active — confirm before replacing it, since starting a
    // new one ends the current pod (it's recorded in history, not lost). The
    // dialog shows the swap visually so it's clear at a glance why it appeared.
    final active = widget.controller.session;
    if (active != null) {
      final ok = await showReplacePodDialog(
        context: context,
        currentSite: active.site,
        currentWorn: active.worn(DateTime.now()),
        newSite: _selectedSite!,
        newStart: _start,
      );
      if (ok != true || !mounted) return;
    }

    widget.controller.startPod(
      startedAt: _useNow ? null : _customStart,
      site: _selectedSite!,
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Closes the sheet asking the bottom bar to switch to the Stock tab so the
  /// user can restock before starting a pod.
  void _goToStock() => Navigator.of(context).pop('stock');

  @override
  Widget build(BuildContext context) {
    // "Now" → current time; "Custom" → the chosen time.
    final start = _start;
    final outOfStock = widget.controller.stock <= 0;

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
                Center(child: Text(fmtStartsAt(start), style: AppText.caption)),
                const SizedBox(height: 20),
                if (outOfStock) ...[
                  _outOfStockCard(),
                  const SizedBox(height: 16),
                  _goToStockButton(),
                ] else
                  _startButton(enabled: _selectedSite != null),
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

  /// [enabled] is false until the user picks an insertion site — the button
  /// greys out and taps are ignored so a site choice is required before start.
  Widget _startButton({required bool enabled}) {
    return GestureDetector(
      onTap: enabled ? _startPod : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.blue : AppColors.chipBorder,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.35),
                    blurRadius: 9,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text('Start Pod', style: AppText.button.copyWith(fontSize: 16)),
      ),
    );
  }

  /// Shown in place of the stock caption when there are no pods left. Warns the
  /// user that a new pod can't be started until they restock.
  Widget _outOfStockCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.endRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.endRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 20, color: AppColors.endRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '0 pods in stock',
                  style: AppText.rowTitle.copyWith(
                    fontSize: 15,
                    color: AppColors.endRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add pods to your stock before starting a new session.',
                  style: AppText.sheetSubtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Replaces "Start Pod" when out of stock — pops the sheet and asks the
  /// bottom bar to open the Stock tab.
  Widget _goToStockButton() {
    return GestureDetector(
      onTap: _goToStock,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.white),
            const SizedBox(width: 8),
            Text('Go to Stock', style: AppText.button.copyWith(fontSize: 16)),
          ],
        ),
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

