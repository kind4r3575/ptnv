import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A pill chip used in the Add Pod (insertion site) and End Pod (reason) sheets.
/// Selected = cyan-bg fill + 1.5px cyan border + navy SemiBold text; otherwise
/// white fill + [AppColors.chipBorder] outline + slate Medium text.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.cyanBg : AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.cyan : AppColors.chipBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: selected ? AppText.chipLabelSelected : AppText.chipLabel,
        ),
      ),
    );
  }
}

/// Lays out a list of [SelectableChip]s in a 3-column grid (used for the 6-item
/// site / reason grids). [labels] length should be a multiple of 3.
class ChipGrid extends StatelessWidget {
  const ChipGrid({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label) => Expanded(
          child: SelectableChip(
            label: label,
            selected: label == selected,
            onTap: () => onSelected(label),
          ),
        );
    Widget row(List<String> three) => Row(
          children: [
            cell(three[0]),
            const SizedBox(width: 8),
            cell(three[1]),
            const SizedBox(width: 8),
            cell(three[2]),
          ],
        );

    final rows = <Widget>[];
    for (var i = 0; i < labels.length; i += 3) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(row(labels.sublist(i, i + 3)));
    }
    return Column(children: rows);
  }
}

/// The two-option pill toggle (e.g. `Now | Custom`). The selected side gets a
/// white pill with a soft shadow over the [AppColors.surfaceAlt] track.
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
  });

  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  Widget _seg(String label, {required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                )
              : null,
          child: Text(label, style: selected ? AppText.segLabelSelected : AppText.segLabel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _seg(leftLabel, selected: leftSelected, onTap: onLeft),
          _seg(rightLabel, selected: !leftSelected, onTap: onRight),
        ],
      ),
    );
  }
}
