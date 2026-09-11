import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/pod.dart';
import '../theme/tokens.dart';
import 'confirm_dialog.dart';

/// Opens the Pod Type picker (Pod Settings). Lists every bundled and
/// user-added [PodTypePreset]; picking one applies its duration/grace as the
/// new defaults via [PodController.applyPodTypePreset] — so Pod Type
/// actually changes behavior instead of just relabeling a fixed pair. Also
/// offers adding (and removing) a custom type.
Future<void> showPodTypePickerSheet(BuildContext context, PodController controller) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.navy.withValues(alpha: 0.45),
    builder: (_) => _PodTypePickerSheet(controller: controller),
  );
}

class _PodTypePickerSheet extends StatelessWidget {
  const _PodTypePickerSheet({required this.controller});

  final PodController controller;

  Future<void> _addCustomType(BuildContext context) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.navy.withValues(alpha: 0.45),
      builder: (_) => _AddCustomPodTypeSheet(controller: controller),
    );
    // Adding also applies it immediately (like picking any other preset), so
    // close the picker too rather than leaving it open on the updated list.
    if (added == true && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _removeCustomType(BuildContext context, PodTypePreset preset) async {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Remove "${preset.name}"?',
      message: 'This custom pod type will no longer show up in the picker. Your current '
          'Default Pod Duration and Grace Period are not affected.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (ok == true) controller.removeCustomPodType(preset.name);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final presets = controller.podTypePresets;
        final customNames = controller.customPodTypes.map((p) => p.name).toSet();
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                    _header(context),
                    const SizedBox(height: 12),
                    for (final preset in presets)
                      _PresetRow(
                        preset: preset,
                        selected: preset.label == controller.podType,
                        removable: customNames.contains(preset.name),
                        onTap: () {
                          controller.applyPodTypePreset(preset);
                          Navigator.of(context).pop();
                        },
                        onRemove: () => _removeCustomType(context, preset),
                      ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _addCustomType(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.cyanBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('＋ Add custom type',
                            style:
                                AppText.rowValue.copyWith(color: AppColors.blue, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pod Type', style: AppText.sheetTitle),
              const SizedBox(height: 4),
              Text('Choose your pod model — applies its default wear and grace time.',
                  style: AppText.sheetSubtitle),
            ],
          ),
        ),
        const SizedBox(width: 12),
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
}

/// One pod-type row: name + "72h wear · 8h grace" subtitle so picking it is
/// an informed choice, not a guess. Custom (user-added) presets get a
/// trailing remove button.
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.selected,
    required this.removable,
    required this.onTap,
    required this.onRemove,
  });

  final PodTypePreset preset;
  final bool selected;
  final bool removable;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.cyanBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    preset.name,
                    style: AppText.rowValue.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('${preset.durationHours}h wear · ${preset.graceHours}h grace',
                      style: AppText.sheetSubtitle),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_rounded, size: 22, color: AppColors.blue),
            if (removable)
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.slate),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small form for naming a custom pod type and giving it a duration/grace.
/// Pops `true` once [PodController.addCustomPodType] has been called, so the
/// picker sheet above knows to close too.
class _AddCustomPodTypeSheet extends StatefulWidget {
  const _AddCustomPodTypeSheet({required this.controller});

  final PodController controller;

  @override
  State<_AddCustomPodTypeSheet> createState() => _AddCustomPodTypeSheetState();
}

class _AddCustomPodTypeSheetState extends State<_AddCustomPodTypeSheet> {
  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '72');
  final _graceController = TextEditingController(text: '8');

  bool get _canAdd => _nameController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _graceController.dispose();
    super.dispose();
  }

  void _add() {
    if (!_canAdd) return;
    widget.controller.addCustomPodType(
      name: _nameController.text,
      durationHours: int.tryParse(_durationController.text.trim()) ?? 72,
      graceHours: int.tryParse(_graceController.text.trim()) ?? 0,
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Custom Type', style: AppText.sheetTitle),
              const SizedBox(height: 4),
              Text('Name it, and set its default wear and grace time.',
                  style: AppText.sheetSubtitle),
              const SizedBox(height: 16),
              Text('NAME', style: AppText.eyebrow),
              const SizedBox(height: 8),
              _textField(_nameController, hint: 'e.g. Tandem t:slim'),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DURATION (HOURS)', style: AppText.eyebrow),
                        const SizedBox(height: 8),
                        _numberField(_durationController),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GRACE (HOURS)', style: AppText.eyebrow),
                        const SizedBox(height: 8),
                        _numberField(_graceController),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _canAdd ? _add : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _canAdd ? AppColors.blue : AppColors.chipBorder,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Add', style: AppText.button.copyWith(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, {String? hint}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.7), width: 1.5),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}), // keeps the Add button's enabled state live
        style: AppText.rowValue.copyWith(fontSize: 15),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppText.sheetSubtitle,
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.7), width: 1.5),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppText.rowValue.copyWith(fontSize: 15),
        decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
      ),
    );
  }
}
