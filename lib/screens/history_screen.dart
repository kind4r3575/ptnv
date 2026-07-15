import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../theme/tokens.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/home_parts.dart';

/// The Session History screen (Figma node `30:2`): a scroll of past-session
/// cards. Log view only. The cards read from [PodController.history]; that list
/// is currently seeded in memory and will be backed by a database later.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.controller});

  final PodController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return Column(
              children: [
                AppBarWave(
                  title: 'History',
                  leading: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                    splashRadius: 22,
                  ),
                ),
                Expanded(child: _body(context)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: appBottomBar(context, controller, 3),
    );
  }

  Widget _body(BuildContext context) {
    final items = controller.history;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: 14),
            Text('No pod history yet', style: AppText.emptyTitle.copyWith(fontSize: 20)),
            const SizedBox(height: 6),
            Text('Finished pods show up here.', style: AppText.emptySub),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, i) => SessionHistoryCard(record: items[i]),
    );
  }
}

/// One past-session card rendered exactly per the Figma design.
class SessionHistoryCard extends StatelessWidget {
  const SessionHistoryCard({super.key, required this.record});

  final SessionRecord record;

  ({String label, Color fg, Color bg}) get _badge {
    switch (record.outcome) {
      case HistoryOutcome.endedEarly:
        return (label: 'Ended early', fg: AppColors.amberText, bg: AppColors.amberBg);
      case HistoryOutcome.wornTooLong:
        return (label: 'Worn too long', fg: AppColors.redText, bg: AppColors.redBg);
      case HistoryOutcome.completed:
        return (label: 'Completed', fg: AppColors.green, bg: AppColors.green.withValues(alpha: 0.14));
    }
  }

  ({String text, Color color}) get _note {
    switch (record.outcome) {
      case HistoryOutcome.endedEarly:
        return (text: 'Changed ${fmtHm(record.planned - record.worn)} early', color: AppColors.amberText);
      case HistoryOutcome.wornTooLong:
        return (text: 'Worn ${fmtHm(record.worn - record.planned)} too long', color: AppColors.redText);
      case HistoryOutcome.completed:
        return (text: 'Worn the full ${record.planned.inHours}h', color: AppColors.green);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    final note = _note;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fmtDate(record.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sheetTitle.copyWith(fontSize: 19),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: badge.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: badge.fg, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(badge.label,
                        style: AppText.badge.copyWith(color: badge.fg, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const _CardDivider(),
          _PairRow(
            leftLabel: 'STARTED',
            leftValue: fmtExpiry(record.started),
            rightLabel: 'ENDED',
            rightValue: fmtExpiry(record.ended),
          ),
          const _CardDivider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WORN', style: AppText.statLabel),
                    const SizedBox(height: 2),
                    Text(fmtHm(record.worn), style: AppText.sheetTitle.copyWith(fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PLANNED', style: AppText.statLabel),
                    const SizedBox(height: 2),
                    Text('${record.planned.inHours}h',
                        style: AppText.statValue.copyWith(fontSize: 16, color: AppColors.slate)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HistoryBar(record: record),
          const SizedBox(height: 8),
          Text(note.text, style: AppText.caption.copyWith(color: note.color)),
          const _CardDivider(),
          _PairRow(
            leftLabel: 'PLACED ON',
            leftValue: record.placedOn,
            rightLabel: 'WHY CHANGED',
            rightValue: record.whyChanged,
          ),
          const SizedBox(height: 14),
          _PairRow(
            leftLabel: 'REMINDERS',
            leftValue: '${record.remindersSent} sent',
            rightLabel: 'CHANGES',
            rightValue: record.changes,
          ),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: AppColors.divider),
      );
}

/// Two side-by-side eyebrow + value columns.
class _PairRow extends StatelessWidget {
  const _PairRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  Widget _col(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.statLabel),
          const SizedBox(height: 2),
          Text(value, style: AppText.statValue),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _col(leftLabel, leftValue)),
        Expanded(child: _col(rightLabel, rightValue)),
      ],
    );
  }
}

/// Worn-vs-planned bar: blue fill = worn/72, with a red overflow cap when the
/// pod was worn too long.
class _HistoryBar extends StatelessWidget {
  const _HistoryBar({required this.record});

  final SessionRecord record;

  @override
  Widget build(BuildContext context) {
    final tooLong = record.outcome == HistoryOutcome.wornTooLong;
    final fraction =
        (record.worn.inMinutes / record.planned.inMinutes).clamp(0.0, 1.0);
    return SizedBox(
      height: 8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final fillW = fraction <= 0 ? 0.0 : (w * fraction).clamp(8.0, w);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.progressTrack,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: fillW,
                decoration: BoxDecoration(
                  color: AppColors.progressFill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (tooLong)
                Positioned(
                  right: 0,
                  child: Container(
                    width: w * 0.07,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.endRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
