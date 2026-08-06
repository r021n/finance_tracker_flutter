import 'package:finance_tracker/src/core/utils/color_utils.dart';
import 'package:finance_tracker/src/shared/constants/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import '../providers/category_providers.dart';

class AddCategoryDialog extends ConsumerStatefulWidget {
  const AddCategoryDialog({super.key, this.type = CategoryType.expense});

  final CategoryType type;

  @override
  ConsumerState<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late CategoryType _type;
  late String _icon;
  late String _color;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _icon = 'other';
    _color = '#4CAF50';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(categoryListProvider.notifier)
        .addCategory(
          name: _nameController.text.trim(),
          type: _type,
          icon: _icon,
          color: _color,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Kategori'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: "Nama Kategori",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Nama wajib diisi" : null,
              ),
              const SizedBox(height: 16),
              SegmentedButton<CategoryType>(
                segments: const [
                  ButtonSegment(
                    value: CategoryType.expense,
                    label: Text("Pengeluaran"),
                  ),
                  ButtonSegment(
                    value: CategoryType.income,
                    label: Text('Pemasukan'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 16),
              _DialogIconPicker(
                selected: _icon,
                onChanged: (value) => setState(() => _icon = value),
              ),
              const SizedBox(height: 12),
              _DialogColorPicker(
                selected: _color,
                onChanged: (value) => setState(() => _color = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

class _DialogIconPicker extends StatelessWidget {
  const _DialogIconPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final entry in kAppIcons.entries)
          ChoiceChip(
            avatar: Icon(entry.value, size: 18),
            label: const SizedBox.shrink(),
            selected: entry.key == selected,
            onSelected: (_) => onChanged(entry.key),
          ),
      ],
    );
  }
}

class _DialogColorPicker extends StatelessWidget {
  const _DialogColorPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const _colors = [
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

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final hex in _colors)
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
    );
  }
}
