import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'option_picker_sheet.dart';

/// Shared building blocks for the Settings and Pod Settings screens: the white
/// card, section header, divider, number box, value/chevron row and link row.

/// The white rounded card that wraps a settings block.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
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
        child: child,
      );
}

/// A group heading above a card (e.g. "Pod Settings").
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
        child: Text(title, style: AppText.sheetTitle.copyWith(fontSize: 20)),
      );
}

/// A thin divider between rows inside a card.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: AppColors.divider),
      );
}

/// Open the bottom-sheet picker for a string-valued row and apply the choice.
Future<void> pickStringOption(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<String> options,
  required String current,
  required ValueChanged<String> onPicked,
}) async {
  final picked = await showOptionPickerSheet<String>(
    context: context,
    title: title,
    subtitle: subtitle,
    options: options,
    selected: current,
    labelOf: (v) => v,
  );
  if (picked != null) onPicked(picked);
}

/// A bordered number field with a right-aligned unit label (Duration, Low Stock).
class SettingsNumberBox extends StatefulWidget {
  const SettingsNumberBox({
    super.key,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  State<SettingsNumberBox> createState() => _SettingsNumberBoxState();
}

class _SettingsNumberBoxState extends State<SettingsNumberBox> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.value}');
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SettingsNumberBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reflect an external value change (e.g. Reset to Defaults) unless the
    // field already shows it (don't fight the user mid-typing).
    if (widget.value != oldWidget.value &&
        int.tryParse(_controller.text.trim()) != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  void _onFocusChange() {
    // On blur, if the field is empty/invalid, restore the current value so it
    // never sits blank with a stale value underneath.
    if (!_focusNode.hasFocus && int.tryParse(_controller.text.trim()) == null) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final v = int.tryParse(raw.trim());
    if (v != null) widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppText.rowValue.copyWith(fontSize: 18),
              onChanged: _commit,
              onSubmitted: _commit,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
          Text(widget.unit, style: AppText.rowTitle),
        ],
      ),
    );
  }
}

/// Label + value + chevron, tappable (opens a picker).
class SettingsValueRow extends StatelessWidget {
  const SettingsValueRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.rowValue)),
          Text(value, style: AppText.rowTitle),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.slate, size: 22),
        ],
      ),
    );
  }
}

/// Label + chevron, tappable. Pass [color] to tint both the label and chevron
/// (used for destructive rows like Clear History / Reset to Defaults).
class SettingsLinkRow extends StatelessWidget {
  const SettingsLinkRow({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: color == null
                  ? AppText.rowValue
                  : AppText.rowValue.copyWith(color: color),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color ?? AppColors.slate, size: 22),
        ],
      ),
    );
  }
}
