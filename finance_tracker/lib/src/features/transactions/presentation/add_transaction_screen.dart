import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/color_utils.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/constants/app_icons.dart';
import '../../wallets/providers/wallet_providers.dart';
import '../../categories/providers/category_providers.dart';
import '../domain/transaction.dart';
import '../providers/transaction_providers.dart';
import 'widgets/numeric_keypad.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.transaction});

  final Transaction? transaction;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TransactionType _type;
  String? _selectedWalletId;
  String? _selectedCategoryId;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String _amountText = '';
  final _noteController = TextEditingController();

  bool get _isEdit => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    if (t != null) {
      _type = t.type;
      _selectedWalletId = t.walletId;
      _selectedCategoryId = t.categoryId;
      _selectedDate = DateTime.parse(t.transactionDate);
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
      _amountText = t.amount.toStringAsFixed(0);
      _noteController.text = t.note ?? '';
    } else {
      _type = TransactionType.expense;
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get _formattedDate {
    return '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
  }

  double get _amount => double.tryParse(_amountText) ?? 0;

  void _onKeyPressed(String key) {
    setState(() {
      if (key == '.' && _amountText.contains('.')) return;
      if (key == '.' && _amountText.isEmpty) {
        _amountText = '0.';
        return;
      }
      _amountText += key;
    });
  }

  void _onBackspace() {
    if (_amountText.isNotEmpty) {
      setState(() {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal harus lebih dari 0')),
      );
      return;
    }
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet terlebih dahulu')),
      );
      return;
    }

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final transactionDate = dateTime.toIso8601String();

    final notifier = ref.read(transactionListProvider.notifier);

    if (_isEdit) {
      await notifier.updateTransaction(
        widget.transaction!.copyWith(
          walletId: _selectedWalletId ?? widget.transaction!.walletId,
          categoryId: _selectedCategoryId,
          amount: _amount,
          type: _type,
          transactionDate: transactionDate,
          note: _noteController.text.isEmpty ? null : _noteController.text,
        ),
      );
    } else {
      await notifier.addTransaction(
        walletId: _selectedWalletId!,
        categoryId: _selectedCategoryId,
        amount: _amount,
        type: _type,
        transactionDate: transactionDate,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletListProvider);
    final categoriesAsync = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Transaksi' : 'Tambah Transaksi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 24),
            Text('Nominal', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              formatCurrency(_amount),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            NumericKeypad(
              onKeyPressed: _onKeyPressed,
              onBackspace: _onBackspace,
            ),
            const SizedBox(height: 24),
            walletAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (wallets) {
                // Auto-select wallet pertama jika belum dipilih
                if (_selectedWalletId == null && wallets.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _selectedWalletId = wallets.first.id);
                  });
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedWalletId,
                  decoration: const InputDecoration(
                    labelText: 'Dompet',
                    border: OutlineInputBorder(),
                  ),
                  items: wallets
                      .map(
                        (w) => DropdownMenuItem(value: w.id, child: Text(w.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedWalletId = v),
                );
              },
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
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            Icon(
                              iconFromName(c.icon),
                              size: 18,
                              color: colorFromHex(c.color),
                            ),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_formattedDate),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEdit ? 'Simpan' : 'Tambah'),
            ),
          ],
        ),
      ),
    );
  }
}
