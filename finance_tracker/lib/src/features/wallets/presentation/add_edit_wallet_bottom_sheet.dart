import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/utils/color_utils.dart";
import "../../../shared/constants/app_icons.dart";
import "../domain/wallet.dart";
import "../providers/wallet_providers.dart";

class AddEditWalletBottomSheet extends ConsumerStatefulWidget {
  const AddEditWalletBottomSheet({super.key, this.wallet});

  final Wallet? wallet;

  @override
  ConsumerState<AddEditWalletBottomSheet> createState() =>
      _AddEditWalletBottomSheetState();
}

class _AddEditWalletBottomSheetState
    extends ConsumerState<AddEditWalletBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;

  late WalletType _type;
  late String _icon;
  late String _color;

  bool get _isEdit => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final w = widget.wallet;
    _nameController = TextEditingController(text: w?.name);
    _balanceController = TextEditingController(
      text: w == null ? "" : w.balance.toStringAsFixed(0),
    );
    _type = w?.type ?? WalletType.cash;
    _icon = w?.icon ?? "wallet";
    _color = w?.color ?? "#4CAF50";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(walletListProvider.notifier);
    if (_isEdit) {
      final w = widget.wallet!;
      await notifier.editWallet(
        w.copyWith(
          name: _nameController.text,
          type: _type,
          icon: _icon,
          color: _color,
        ),
      );
    } else {
      await notifier.addWallet(
        name: _nameController.text.trim(),
        type: _type,
        initialBalance: double.tryParse(_balanceController.text) ?? 0,
        icon: _icon,
        color: _color,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? "Edit Dompet" : "Tambah Dompet",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Nama Dompet",
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Nama wajib diisi" : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<WalletType>(
              segments: const [
                ButtonSegment(value: WalletType.cash, label: Text("Cash")),
                ButtonSegment(value: WalletType.bank, label: Text("Bank")),
                ButtonSegment(
                  value: WalletType.eWallet,
                  label: Text("E-Wallet"),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            if (!_isEdit)
              TextFormField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: "Saldo Awal",
                  border: OutlineInputBorder(),
                ),
              ),
            if (!_isEdit) const SizedBox(height: 16),
            _ColorPickerField(
              selected: _color,
              onChanged: (value) => setState(() => _color = value),
            ),
            const SizedBox(height: 12),
            _IconPickerField(
              selected: _icon,
              onChanged: (value) => setState(() => _icon = value),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEdit ? "Simpan" : "Tambah"),
            ),
          ],
        ),
      ),
    );
  }
}

const _presetColors = [
  '#4CAF50',
  '#F44336',
  '#2196F3',
  '#FF9800',
  '#9C27B0',
  '#00BCD4',
  '#FFEB3B',
  '#795548',
  '#607D8B',
  '#E91E63',
];

class _ColorPickerField extends StatelessWidget {
  const _ColorPickerField({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedColor = colorFromHex(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Warna", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in _presetColors)
              GestureDetector(
                onTap: () => onChanged(hex),
                child: CircleAvatar(
                  backgroundColor: colorFromHex(hex),
                  child: hex == selected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Terpilih: $selectedColor",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _IconPickerField extends StatelessWidget {
  const _IconPickerField({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Ikon", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in kAppIcons.entries)
              ChoiceChip(
                avatar: Icon(entry.value, size: 18),
                label: const SizedBox.shrink(),
                selected: entry.key == selected,
                onSelected: (_) => onChanged(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}
