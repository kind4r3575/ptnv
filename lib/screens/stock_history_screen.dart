import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../theme/tokens.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/home_parts.dart';

/// Full Pod Stock activity log (Figma node `243:85`), reached from "See all ›"
/// on the Stock screen. Shows an on-hand / last-restock summary card, then the
/// activity grouped into per-month cards, each row carrying a signed delta chip,
/// a two-line label/detail, and the entry date.
class StockHistoryScreen extends StatelessWidget {
  const StockHistoryScreen({super.key, required this.controller});

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
                  title: 'Stock history',
                  leading: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                    splashRadius: 22,
                  ),
                ),
                Expanded(child: _body()),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: appBottomBar(context, controller, 1),
    );
  }

  Widget _body() {
    final items = controller.activity;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryCard(stock: controller.stock, lastRestock: _lastRestock(items)),
          const SizedBox(height: 20),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text('No activity yet', style: AppText.emptySub)),
            )
          else
            for (final group in _groupByMonth(items)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
                child: Text(
                  fmtMonthYearUpper(group.first.at),
                  style: AppText.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              _MonthCard(entries: group),
              const SizedBox(height: 18),
            ],
        ],
      ),
    );
  }

  /// The most recent positive-delta (restock) entry, or null if none yet.
  StockActivity? _lastRestock(List<StockActivity> items) {
    for (final e in items) {
      if (e.delta > 0) return e;
    }
    return null;
  }

  /// Split the newest-first activity into consecutive same-month groups.
  List<List<StockActivity>> _groupByMonth(List<StockActivity> items) {
    final groups = <List<StockActivity>>[];
    for (final e in items) {
      final last = groups.isEmpty ? null : groups.last.first.at;
      if (last == null || last.year != e.at.year || last.month != e.at.month) {
        groups.add([e]);
      } else {
        groups.last.add(e);
      }
    }
    return groups;
  }
}

/// The white, cyan-outlined card used for both the summary and each month group.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Top summary: pods on hand (left) and the last restock (right).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stock, required this.lastRestock});

  final int stock;
  final StockActivity? lastRestock;

  @override
  Widget build(BuildContext context) {
    final r = lastRestock;
    return _HistoryCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ON HAND', style: AppText.eyebrow),
                const SizedBox(height: 4),
                Text('$stock pods', style: AppText.emptyTitle.copyWith(fontSize: 26)),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('LAST RESTOCK', style: AppText.eyebrow),
                const SizedBox(height: 4),
                Text(
                  r == null ? '—' : '${fmtMonthDay(r.at)} · +${r.delta}',
                  style: AppText.statValue.copyWith(
                    fontSize: 15,
                    color: r == null ? AppColors.slate : AppColors.stockGreenText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One month's worth of activity rows, divided by hairlines.
class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.entries});

  final List<StockActivity> entries;

  @override
  Widget build(BuildContext context) {
    return _HistoryCard(
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.divider,
                indent: 16,
                endIndent: 16,
              ),
            _ActivityRow(entry: entries[i]),
          ],
        ],
      ),
    );
  }
}

/// A single history row: signed delta chip, label + optional detail, date.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final StockActivity entry;

  @override
  Widget build(BuildContext context) {
    final positive = entry.delta > 0;
    final chipBg = positive ? AppColors.stockGreenBg : AppColors.surfaceAlt2;
    final chipFg = positive ? AppColors.stockGreenText : AppColors.slate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              positive ? '+${entry.delta}' : '−${entry.delta.abs()}',
              style: AppText.badge.copyWith(fontSize: 14, color: chipFg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.label, style: AppText.statValue.copyWith(fontSize: 15)),
                if (entry.note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(entry.note, style: AppText.sheetSubtitle),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(fmtMonthDay(entry.at), style: AppText.caption.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

/// A compact single-line activity row — the signed delta and one caption line.
/// Kept for the "Recent activity" preview on the Stock screen.
class StockActivityRow extends StatelessWidget {
  const StockActivityRow({super.key, required this.entry});

  final StockActivity entry;

  @override
  Widget build(BuildContext context) {
    final positive = entry.delta > 0;
    final color = positive ? AppColors.green : AppColors.endRed;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            positive ? '+${entry.delta}' : '${entry.delta}',
            style: AppText.statValue.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${entry.label} · ${fmtActivityTime(entry.at)}',
            style: AppText.caption,
          ),
        ),
      ],
    );
  }
}
