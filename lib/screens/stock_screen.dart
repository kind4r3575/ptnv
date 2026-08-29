import 'package:flutter/material.dart';

import '../state/pod.dart';
import '../theme/tokens.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_switch.dart';
import '../widgets/home_parts.dart';
import '../widgets/page_transitions.dart';
import 'stock_history_screen.dart';

/// The Pod Stock screen (Figma node `20:2`): adjust the pod count with the
/// −/+ steppers, see the estimated days of supply (stock × 3), set an exact
/// amount, review recent activity, and toggle the reorder reminder.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key, required this.controller});

  final PodController controller;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final TextEditingController _amount = TextEditingController();

  PodController get _c => widget.controller;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _setExact() {
    final value = int.tryParse(_amount.text.trim());
    if (value == null || value < 0) return;
    _c.setStock(value);
    _amount.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            return Column(
              children: [
                AppBarWave(
                  title: 'Pod Stock',
                  leading: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                    splashRadius: 22,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    child: Column(
                      children: [
                        _currentStockCard(),
                        const SizedBox(height: 16),
                        _daysOfSupplyCard(),
                        const SizedBox(height: 16),
                        _setExactCard(),
                        const SizedBox(height: 16),
                        _recentActivityCard(),
                        const SizedBox(height: 16),
                        _reorderCard(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: appBottomBar(context, _c, 1),
    );
  }

  // --- Cards ----------------------------------------------------------------

  Widget _card({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  ({String label, Color fg, Color bg}) _statusBadge() {
    final stock = _c.stock;
    if (stock == 0) {
      return (label: 'Out of stock', fg: AppColors.redText, bg: AppColors.redBg);
    }
    if (stock <= _c.lowStockThreshold) {
      return (label: 'Low', fg: AppColors.amberText, bg: AppColors.amberBg);
    }
    return (label: 'In stock', fg: AppColors.green, bg: AppColors.green.withValues(alpha: 0.14));
  }

  Widget _currentStockCard() {
    final badge = _statusBadge();
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Text('CURRENT STOCK', style: AppText.eyebrow),
              const Spacer(),
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepButton(
                key: const ValueKey('stockMinus'),
                icon: Icons.remove_rounded,
                color: AppColors.endRed,
                onTap: () => _c.adjustStock(-1),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${_c.stock}', style: AppText.bigTime.copyWith(fontSize: 56)),
                  Text('pods', style: AppText.rowTitle),
                ],
              ),
              _StepButton(
                key: const ValueKey('stockPlus'),
                icon: Icons.add_rounded,
                color: AppColors.green,
                onTap: () => _c.adjustStock(1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _daysOfSupplyCard() {
    // When stock is low/out, tint the card + "Days of supply left" to match the
    // status badge (amber = low, red = out) — otherwise the normal cyan.
    final out = _c.stock == 0;
    final low = _c.stock <= _c.lowStockThreshold;
    final accent = out
        ? AppColors.redText
        : (low ? AppColors.amberText : AppColors.cyan);
    final bg = out
        ? AppColors.redBg
        : (low ? AppColors.amberBg : AppColors.cyanBg);
    final valueColor = (out || low) ? accent : AppColors.navy;
    return _card(
      color: bg,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: const Icon(Icons.schedule_rounded, color: AppColors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAYS OF SUPPLY LEFT',
                    style: AppText.statLabel.copyWith(
                        color: (out || low) ? accent : null)),
                const SizedBox(height: 2),
                Text('≈ ${_c.daysOfSupply} days',
                    style: AppText.sheetTitle.copyWith(fontSize: 22, color: valueColor)),
                const SizedBox(height: 2),
                Text(
                  'Runs out around ${fmtMonthDay(_c.runsOutDate)} · '
                  'low at ${_c.lowStockThreshold} pods',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _setExactCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set exact amount', style: AppText.rowValue),
          const SizedBox(height: 2),
          Text('Type how many pods you actually have', style: AppText.sheetSubtitle),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  style: AppText.rowValue,
                  onSubmitted: (_) => _setExact(),
                  decoration: InputDecoration(
                    hintText: 'Enter amount',
                    hintStyle: AppText.rowTitle,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.cyan.withValues(alpha: 0.6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _setExact,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Set', style: AppText.button.copyWith(fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recentActivityCard() {
    final items = _c.activity;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Recent activity', style: AppText.rowValue),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  fadePushRoute(StockHistoryScreen(controller: _c)),
                ),
                behavior: HitTestBehavior.opaque,
                child: Text('See all ›',
                    style: AppText.caption
                        .copyWith(color: AppColors.blue, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text('No activity yet', style: AppText.caption)
          else
            for (var i = 0; i < items.length && i < 2; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: StockActivityRow(entry: items[i])),
                  if (i == 0) ...[
                    const SizedBox(width: 8),
                    _UndoButton(onTap: _c.undoLastActivity),
                  ],
                ],
              ),
            ],
        ],
      ),
    );
  }

  Widget _reorderCard() {
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remind me to reorder', style: AppText.rowValue),
                const SizedBox(height: 2),
                Text('When stock drops to ${_c.lowStockThreshold} pods',
                    style: AppText.sheetSubtitle),
              ],
            ),
          ),
          AppSwitch(value: _c.reorderReminder, onChanged: _c.setReorderReminder),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.white, size: 30),
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: Text('Undo',
            style: AppText.caption.copyWith(color: AppColors.navy, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
