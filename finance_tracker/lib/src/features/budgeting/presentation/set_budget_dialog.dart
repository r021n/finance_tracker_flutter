import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../categories/providers/category_providers.dart";

class SetBudgetDialog extends ConsumerStatefulWidget {
  const SetBudgetDialog({super.key});

  @override
  ConsumerState<SetBudgetDialog> createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends ConsumerState<SetBudgetDialog> {
  String? _selectedCategoryId;
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori terlebih dahulu')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal harus lebih dari 0')),
      );
      return;
    }

    Navigator.of(
      context,
    ).pop({'categoryId': _selectedCategoryId!, 'amountLimit': amount});
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);

    return AlertDialog(
      title: const Text('Atur Anggaran'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            categoriesAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Gagal memuat kategori: $e'),
              data: (categories) {
                final expenseCategories = categories
                    .where((c) => c.type.name == 'expense')
                    .toList();
                return DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: expenseCategories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Batas Anggaran (Rp)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
