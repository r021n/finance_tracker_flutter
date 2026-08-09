import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wallets/providers/wallet_providers.dart';
import '../../categories/providers/category_providers.dart';
import '../domain/transaction.dart';
import '../domain/recurring_rule.dart';
import '../providers/transaction_providers.dart';

class AddRecurringRuleScreen extends ConsumerStatefulWidget {
  const AddRecurringRuleScreen({super.key});

  @override
  ConsumerState<AddRecurringRuleScreen> createState() =>
      _AddRecurringRuleScreenState();
}

class _AddRecurringRuleScreenState
    extends ConsumerState<AddRecurringRuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  String? _selectedWalletId;
  String? _selectedCategoryId;
  late DateTime _nextRunDate;

  @override
  void initState() {
    super.initState();
    _nextRunDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _formattedNextRunDate {
    return '${_nextRunDate.year}-${_nextRunDate.month.toString().padLeft(2, '0')}-${_nextRunDate.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickNextRunDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextRunDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _nextRunDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet terlebih dahulu')),
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

    await ref
        .read(recurringRuleListProvider.notifier)
        .addRecurringRule(
          walletId: _selectedWalletId!,
          categoryId: _selectedCategoryId,
          amount: amount,
          type: _type,
          frequency: _frequency,
          nextRunDate: _formattedNextRunDate,
          note: _noteController.text.isEmpty ? null : _noteController.text,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletListProvider);
    final categoriesAsync = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Aturan Berulang')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Pengeluaran'),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Pemasukan'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
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
                  labelText: 'Nominal',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Wajib diisi';
                  if ((double.tryParse(v) ?? 0) <= 0) {
                    return 'Harus lebih dari 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RecurringFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Frekuensi',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: RecurringFrequency.daily,
                    child: Text('Harian'),
                  ),
                  DropdownMenuItem(
                    value: RecurringFrequency.weekly,
                    child: Text('Mingguan'),
                  ),
                  DropdownMenuItem(
                    value: RecurringFrequency.monthly,
                    child: Text('Bulanan'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _frequency = v);
                },
              ),
              const SizedBox(height: 16),
              walletsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (wallets) => DropdownButtonFormField<String>(
                  initialValue: _selectedWalletId,
                  decoration: const InputDecoration(
                    labelText: 'Dompet',
                    border: OutlineInputBorder(),
                  ),
                  items: wallets
                      .map(
                        (w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedWalletId = v),
                ),
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (categories) {
                  final filtered = categories
                      .where((c) => c.type.name == _type.name)
                      .toList();
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tanpa Kategori'),
                      ),
                      ...filtered.map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickNextRunDate,
                icon: const Icon(Icons.calendar_today),
                label: Text('Jalankan pertama: $_formattedNextRunDate'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _submit, child: const Text('Simpan')),
            ],
          ),
        ),
      ),
    );
  }
}
