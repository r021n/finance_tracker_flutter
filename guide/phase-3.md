# Panduan Fase 3: Pencatatan Transaksi Utama & Transaksi Berulang

## Ikhtisar

Fase 3 menambahkan fitur pencatatan transaksi (pemasukan/pengeluaran) dan transaksi berulang. Semua file baru dibuat di dalam folder `lib/src/features/transactions/`.

---

## Struktur Folder yang Dibuat

```
lib/src/features/transactions/
  domain/
    transaction.dart
    transaction.freezed.dart    (otomatis)
    transaction.g.dart          (otomatis)
    recurring_rule.dart
    recurring_rule.freezed.dart (otomatis)
    recurring_rule.g.dart       (otomatis)
  data/
    transaction_repository.dart
    recurring_repository.dart
    recurring_checker.dart
  providers/
    transaction_providers.dart
    transaction_providers.g.dart (otomatis)
  presentation/
    widgets/
      numeric_keypad.dart
    add_transaction_screen.dart
    transaction_history_screen.dart
    transaction_detail_bottom_sheet.dart
    recurring_list_screen.dart
    add_recurring_rule_screen.dart
```

---

## Langkah 1: Buat Model Transaction

Buat file `lib/src/features/transactions/domain/transaction.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

enum TransactionType { income, expense }

@freezed
abstract class Transaction with _$Transaction {
  const Transaction._();

  const factory Transaction({
    required String id,
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required String transactionDate,
    String? note,
    String? createdAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}
```

---

## Langkah 2: Buat Model RecurringRule

Buat file `lib/src/features/transactions/domain/recurring_rule.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'transaction.dart';

part 'recurring_rule.freezed.dart';
part 'recurring_rule.g.dart';

enum RecurringFrequency { daily, weekly, monthly }

@freezed
abstract class RecurringRule with _$RecurringRule {
  const RecurringRule._();

  const factory RecurringRule({
    required String id,
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required RecurringFrequency frequency,
    required String nextRunDate,
    String? note,
  }) = _RecurringRule;

  factory RecurringRule.fromJson(Map<String, dynamic> json) =>
      _$RecurringRuleFromJson(json);
}
```

> **PENTING:** `recurring_rule.dart` harus import `transaction.dart` karena menggunakan `TransactionType`.

---

## Langkah 3: Buat TransactionRepository

Buat file `lib/src/features/transactions/data/transaction_repository.dart`:

```dart
import 'package:uuid/uuid.dart';

import '../../../core/database/turso_client.dart';
import '../domain/transaction.dart';

const _uuid = Uuid();

class TransactionRepository {
  TransactionRepository(this._client);

  final TursoClient _client;

  Future<List<Transaction>> getTransactions({
    String? walletId,
    String? categoryId,
    String? startDate,
    String? endDate,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (walletId != null) {
      conditions.add('wallet_id = ?');
      args.add(walletId);
    }
    if (categoryId != null) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }
    if (startDate != null) {
      conditions.add('transaction_date >= ?');
      args.add(startDate);
    }
    if (endDate != null) {
      conditions.add('transaction_date <= ?');
      args.add(endDate);
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final rows = await _client.query(
      'SELECT * FROM transactions $where ORDER BY transaction_date DESC',
      args: args.isEmpty ? null : args,
    );
    return rows.map(Transaction.fromJson).toList();
  }

  Future<Transaction> addTransaction({
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required String transactionDate,
    String? note,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();

    await _client.execute(
      '''
      INSERT INTO transactions (id, wallet_id, category_id, amount, type, transaction_date, note, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      args: [id, walletId, categoryId, amount, type.name, transactionDate, note, now],
    );

    final balanceChange = type == TransactionType.income ? amount : -amount;
    await _client.execute(
      'UPDATE wallets SET balance = balance + ? WHERE id = ?',
      args: [balanceChange, walletId],
    );

    return Transaction(
      id: id,
      walletId: walletId,
      categoryId: categoryId,
      amount: amount,
      type: type,
      transactionDate: transactionDate,
      note: note,
      createdAt: now,
    );
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final old = await _client.query(
      'SELECT * FROM transactions WHERE id = ?',
      args: [transaction.id],
    );
    if (old.isEmpty) return;

    final oldTransaction = Transaction.fromJson(old.first);

    await _client.execute(
      '''
      UPDATE transactions
      SET wallet_id = ?, category_id = ?, amount = ?, type = ?, transaction_date = ?, note = ?
      WHERE id = ?
      ''',
      args: [
        transaction.walletId,
        transaction.categoryId,
        transaction.amount,
        transaction.type.name,
        transaction.transactionDate,
        transaction.note,
        transaction.id,
      ],
    );

    if (oldTransaction.walletId != transaction.walletId) {
      final oldChange = oldTransaction.type == TransactionType.income
          ? -oldTransaction.amount
          : oldTransaction.amount;
      await _client.execute(
        'UPDATE wallets SET balance = balance + ? WHERE id = ?',
        args: [oldChange, oldTransaction.walletId],
      );

      final newChange = transaction.type == TransactionType.income
          ? transaction.amount
          : -transaction.amount;
      await _client.execute(
        'UPDATE wallets SET balance = balance + ? WHERE id = ?',
        args: [newChange, transaction.walletId],
      );
    } else if (oldTransaction.amount != transaction.amount ||
        oldTransaction.type != transaction.type) {
      final oldChange = oldTransaction.type == TransactionType.income
          ? -oldTransaction.amount
          : oldTransaction.amount;
      final newChange = transaction.type == TransactionType.income
          ? transaction.amount
          : -transaction.amount;
      final diff = newChange - oldChange;
      await _client.execute(
        'UPDATE wallets SET balance = balance + ? WHERE id = ?',
        args: [diff, transaction.walletId],
      );
    }
  }

  Future<void> deleteTransaction(String id) async {
    final rows = await _client.query(
      'SELECT * FROM transactions WHERE id = ?',
      args: [id],
    );
    if (rows.isEmpty) return;

    final transaction = Transaction.fromJson(rows.first);

    final rollback = transaction.type == TransactionType.income
        ? -transaction.amount
        : transaction.amount;

    await _client.execute(
      'UPDATE wallets SET balance = balance + ? WHERE id = ?',
      args: [rollback, transaction.walletId],
    );

    await _client.execute('DELETE FROM transactions WHERE id = ?', args: [id]);
  }
}
```

---

## Langkah 4: Buat RecurringRepository

Buat file `lib/src/features/transactions/data/recurring_repository.dart`:

```dart
import 'package:uuid/uuid.dart';

import '../../../core/database/turso_client.dart';
import '../domain/recurring_rule.dart';
import '../domain/transaction.dart';

const _uuid = Uuid();

class RecurringRepository {
  RecurringRepository(this._client);

  final TursoClient _client;

  Future<List<RecurringRule>> getRecurringRules() async {
    final rows = await _client.query(
      'SELECT * FROM recurring_rules ORDER BY next_run_date ASC',
    );
    return rows.map(RecurringRule.fromJson).toList();
  }

  Future<RecurringRule> createRecurringRule({
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required RecurringFrequency frequency,
    required String nextRunDate,
    String? note,
  }) async {
    final id = _uuid.v4();

    await _client.execute(
      '''
      INSERT INTO recurring_rules (id, wallet_id, category_id, amount, type, frequency, next_run_date, note)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      args: [id, walletId, categoryId, amount, type.name, frequency.name, nextRunDate, note],
    );

    return RecurringRule(
      id: id,
      walletId: walletId,
      categoryId: categoryId,
      amount: amount,
      type: type,
      frequency: frequency,
      nextRunDate: nextRunDate,
      note: note,
    );
  }

  Future<void> updateNextRunDate(String id, String nextRunDate) async {
    await _client.execute(
      'UPDATE recurring_rules SET next_run_date = ? WHERE id = ?',
      args: [nextRunDate, id],
    );
  }

  Future<void> deleteRecurringRule(String id) async {
    await _client.execute('DELETE FROM recurring_rules WHERE id = ?', args: [id]);
  }
}
```

---

## Langkah 5: Buat RecurringChecker Service

Buat file `lib/src/features/transactions/data/recurring_checker.dart`:

```dart
import 'package:uuid/uuid.dart';

import '../../../core/database/turso_client.dart';
import '../domain/recurring_rule.dart';
import '../domain/transaction.dart';

const _uuid = Uuid();

class RecurringChecker {
  RecurringChecker(this._client);

  final TursoClient _client;

  Future<void> checkAndRunDueTransactions() async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final rules = await _client.query(
      "SELECT * FROM recurring_rules WHERE next_run_date <= ?",
      args: [todayStr],
    );

    for (final ruleRow in rules) {
      final rule = RecurringRule.fromJson(ruleRow);

      final transactionId = _uuid.v4();
      final createdAt = now.toIso8601String();

      await _client.execute(
        '''
        INSERT INTO transactions (id, wallet_id, category_id, amount, type, transaction_date, note, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        args: [
          transactionId,
          rule.walletId,
          rule.categoryId,
          rule.amount,
          rule.type.name,
          todayStr,
          rule.note,
          createdAt,
        ],
      );

      final balanceChange =
          rule.type == TransactionType.income ? rule.amount : -rule.amount;
      await _client.execute(
        'UPDATE wallets SET balance = balance + ? WHERE id = ?',
        args: [balanceChange, rule.walletId],
      );

      final nextRun = _calculateNextRunDate(rule.frequency, now);
      await _client.execute(
        'UPDATE recurring_rules SET next_run_date = ? WHERE id = ?',
        args: [nextRun, rule.id],
      );
    }
  }

  String _calculateNextRunDate(RecurringFrequency frequency, DateTime from) {
    DateTime next;
    switch (frequency) {
      case RecurringFrequency.daily:
        next = from.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        next = from.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        next = DateTime(from.year, from.month + 1, from.day);
    }
    return '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
  }
}
```

---

## Langkah 6: Buat Providers

Buat file `lib/src/features/transactions/providers/transaction_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/turso_client_provider.dart';
import '../data/transaction_repository.dart';
import '../data/recurring_repository.dart';
import '../domain/transaction.dart';
import '../domain/recurring_rule.dart';

part 'transaction_providers.g.dart';


final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(tursoClientProvider));
});

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(tursoClientProvider));
});

class TransactionFilter {
  const TransactionFilter({
    this.walletId,
    this.categoryId,
    this.startDate,
    this.endDate,
    this.searchQuery,
  });

  final String? walletId;
  final String? categoryId;
  final String? startDate;
  final String? endDate;
  final String? searchQuery;

  TransactionFilter copyWith({
    String? walletId,
    String? categoryId,
    String? startDate,
    String? endDate,
    String? searchQuery,
    bool clearWalletId = false,
    bool clearCategoryId = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearSearchQuery = false,
  }) {
    return TransactionFilter(
      walletId: clearWalletId ? null : (walletId ?? this.walletId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
    );
  }
}

class TransactionFilterState extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => const TransactionFilter();

  void update(TransactionFilter newState) => state = newState;

  void updateWalletId(String? walletId) =>
      state = state.copyWith(walletId: walletId);

  void updateCategoryId(String? categoryId) =>
      state = state.copyWith(categoryId: categoryId);

  void updateStartDate(String? startDate) =>
      state = state.copyWith(startDate: startDate);

  void updateEndDate(String? endDate) =>
      state = state.copyWith(endDate: endDate);

  void updateSearchQuery(String? searchQuery) =>
      state = state.copyWith(searchQuery: searchQuery);

  void clearAll() => state = const TransactionFilter();
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterState, TransactionFilter>(
  TransactionFilterState.new,
);

@Riverpod(keepAlive: true)
class TransactionListNotifier extends _$TransactionListNotifier {
  @override
  Future<List<Transaction>> build() async {
    final filter = ref.watch(transactionFilterProvider);
    return ref.read(transactionRepositoryProvider).getTransactions(
          walletId: filter.walletId,
          categoryId: filter.categoryId,
          startDate: filter.startDate,
          endDate: filter.endDate,
        );
  }

  Future<Transaction> addTransaction({
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required String transactionDate,
    String? note,
  }) async {
    final transaction =
        await ref.read(transactionRepositoryProvider).addTransaction(
              walletId: walletId,
              categoryId: categoryId,
              amount: amount,
              type: type,
              transactionDate: transactionDate,
              note: note,
            );
    ref.invalidateSelf();
    return transaction;
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await ref
        .read(transactionRepositoryProvider)
        .updateTransaction(transaction);
    ref.invalidateSelf();
  }

  Future<void> deleteTransaction(String id) async {
    await ref.read(transactionRepositoryProvider).deleteTransaction(id);
    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
class RecurringRuleListNotifier extends _$RecurringRuleListNotifier {
  @override
  Future<List<RecurringRule>> build() async {
    return ref.read(recurringRepositoryProvider).getRecurringRules();
  }

  Future<void> addRecurringRule({
    required String walletId,
    String? categoryId,
    required double amount,
    required TransactionType type,
    required RecurringFrequency frequency,
    required String nextRunDate,
    String? note,
  }) async {
    await ref.read(recurringRepositoryProvider).createRecurringRule(
          walletId: walletId,
          categoryId: categoryId,
          amount: amount,
          type: type,
          frequency: frequency,
          nextRunDate: nextRunDate,
          note: note,
        );
    ref.invalidateSelf();
  }

  Future<void> deleteRecurringRule(String id) async {
    await ref.read(recurringRepositoryProvider).deleteRecurringRule(id);
    ref.invalidateSelf();
  }
}
```

> **PENTING:** `StateProvider` tidak tersedia di flutter_riverpod 3.2.1. Gunakan `NotifierProvider` dengan class `Notifier` sebagai gantinya.

---

## Langkah 7: Buat UI NumericKeypad

Buat file `lib/src/features/transactions/presentation/widgets/numeric_keypad.dart`:

```dart
import 'package:flutter/material.dart';

class NumericKeypad extends StatelessWidget {
  const NumericKeypad({super.key, required this.onKeyPressed, this.onBackspace, this.onDone});

  final ValueChanged<String> onKeyPressed;
  final VoidCallback? onBackspace;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        _buildRow(['4', '5', '6']),
        _buildRow(['7', '8', '9']),
        _buildRow(['.', '0', '<']),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: [
        for (final key in keys)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AspectRatio(
                aspectRatio: 2,
                child: ElevatedButton(
                  onPressed: () {
                    if (key == '<') {
                      onBackspace?.call();
                    } else {
                      onKeyPressed(key);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: key == '<'
                      ? const Icon(Icons.backspace_outlined)
                      : Text(
                          key,
                          style: const TextStyle(fontSize: 24),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

---

## Langkah 8: Buat AddTransactionScreen

Buat file `lib/src/features/transactions/presentation/add_transaction_screen.dart`:

```dart
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
    final walletsAsync = ref.watch(walletListProvider);
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
            Text(
              'Nominal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              formatCurrency(_amount),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            NumericKeypad(
              onKeyPressed: _onKeyPressed,
              onBackspace: _onBackspace,
            ),
            const SizedBox(height: 24),
            walletsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (wallets) => DropdownButtonFormField<String>(
                value: _selectedWalletId,
                decoration: const InputDecoration(
                  labelText: 'Dompet',
                  border: OutlineInputBorder(),
                ),
                items: wallets
                    .map((w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(w.name),
                        ))
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
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tanpa Kategori'),
                    ),
                    ...filtered.map((c) => DropdownMenuItem(
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
                        )),
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
```

---

## Langkah 9: Buat TransactionHistoryScreen

Buat file `lib/src/features/transactions/presentation/transaction_history_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../shared/constants/app_icons.dart';
import '../../categories/providers/category_providers.dart';
import '../domain/transaction.dart';
import '../providers/transaction_providers.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_bottom_sheet.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddTransactionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat transaksi: $error'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(transactionListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: Text('Belum ada transaksi. Ketuk + untuk menambah.'),
            );
          }

          final grouped = _groupByDate(transactions);
          final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

          return RefreshIndicator(
            onRefresh: () => ref.refresh(transactionListProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                final dayTransactions = grouped[date]!;
                final totalIncome = dayTransactions
                    .where((t) => t.type == TransactionType.income)
                    .fold(0.0, (sum, t) => sum + t.amount);
                final totalExpense = dayTransactions
                    .where((t) => t.type == TransactionType.expense)
                    .fold(0.0, (sum, t) => sum + t.amount);

                return _DateGroupHeader(
                  date: date,
                  totalIncome: totalIncome,
                  totalExpense: totalExpense,
                  children: dayTransactions
                      .map((t) => _TransactionTile(
                            transaction: t,
                            onTap: () => _openDetail(context, t),
                          ))
                      .toList(),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, Transaction transaction) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionDetailBottomSheet(transaction: transaction),
    );
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final map = <String, List<Transaction>>{};
    for (final t in transactions) {
      final dateKey = t.transactionDate.length >= 10
          ? t.transactionDate.substring(0, 10)
          : t.transactionDate;
      map.putIfAbsent(dateKey, () => []).add(t);
    }
    return map;
  }
}

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({
    required this.date,
    required this.totalIncome,
    required this.totalExpense,
    required this.children,
  });

  final String date;
  final double totalIncome;
  final double totalExpense;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date);
    final displayDate = parsed != null
        ? '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}'
        : date;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                displayDate,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              if (totalIncome > 0)
                Text(
                  '+${formatCurrency(totalIncome)}',
                  style: TextStyle(color: Colors.green[700], fontSize: 12),
                ),
              if (totalIncome > 0 && totalExpense > 0) const SizedBox(width: 8),
              if (totalExpense > 0)
                Text(
                  '-${formatCurrency(totalExpense)}',
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction, this.onTap});

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final isExpense = transaction.type == TransactionType.expense;
    final amountColor = isExpense ? Colors.red : Colors.green;
    final prefix = isExpense ? '-' : '+';

    return categoriesAsync.when(
      loading: () => const ListTile(
        leading: CircularProgressIndicator(),
        title: Text('Memuat...'),
      ),
      error: (_, __) => ListTile(
        title: Text(transaction.note ?? 'Transaksi'),
      ),
      data: (categories) {
        final category = transaction.categoryId != null
            ? categories
                .where((c) => c.id == transaction.categoryId)
                .firstOrNull
            : null;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            onTap: onTap,
            leading: CircleAvatar(
              backgroundColor: amountColor.withValues(alpha: 0.1),
              child: Icon(
                category != null ? iconFromName(category.icon) : Icons.receipt,
                color: amountColor,
                size: 20,
              ),
            ),
            title: Text(category?.name ?? 'Tanpa Kategori'),
            subtitle: transaction.note != null
                ? Text(
                    transaction.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Text(
              '$prefix${formatCurrency(transaction.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
```

---

## Langkah 10: Buat TransactionDetailBottomSheet

Buat file `lib/src/features/transactions/presentation/transaction_detail_bottom_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../wallets/providers/wallet_providers.dart';
import '../../categories/providers/category_providers.dart';
import '../domain/transaction.dart';
import '../providers/transaction_providers.dart';
import 'add_transaction_screen.dart';

class TransactionDetailBottomSheet extends ConsumerWidget {
  const TransactionDetailBottomSheet({super.key, required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(walletListProvider);
    final categoriesAsync = ref.watch(categoryListProvider);

    final isExpense = transaction.type == TransactionType.expense;
    final amountColor = isExpense ? Colors.red : Colors.green;
    final prefix = isExpense ? '-' : '+';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Detail Transaksi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            '$prefix${formatCurrency(transaction.amount)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildDetailSection(
            context,
            walletsAsync: walletsAsync,
            categoriesAsync: categoriesAsync,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddTransactionScreen(
                          transaction: transaction,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _confirmDelete(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete),
                  label: const Text('Hapus'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
    BuildContext context, {
    required AsyncValue<List<dynamic>> walletsAsync,
    required AsyncValue<List<dynamic>> categoriesAsync,
  }) {
    final parsed = DateTime.tryParse(transaction.transactionDate);
    final displayDate = parsed != null
        ? '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}'
        : transaction.transactionDate;

    String walletName = '-';
    String categoryName = '-';

    walletsAsync.whenData((wallets) {
      final wallet = wallets.where((w) => w.id == transaction.walletId).firstOrNull;
      if (wallet != null) walletName = wallet.name;
    });

    categoriesAsync.whenData((categories) {
      final category = categories
          .where((c) => c.id == transaction.categoryId)
          .firstOrNull;
      if (category != null) categoryName = category.name;
    });

    return Column(
      children: [
        _DetailRow(
          icon: Icons.account_balance_wallet,
          label: 'Dompet',
          value: walletName,
        ),
        _DetailRow(
          icon: Icons.category,
          label: 'Kategori',
          value: categoryName,
        ),
        _DetailRow(
          icon: Icons.calendar_today,
          label: 'Tanggal',
          value: displayDate,
        ),
        if (transaction.note != null && transaction.note!.isNotEmpty)
          _DetailRow(
            icon: Icons.note,
            label: 'Catatan',
            value: transaction.note!,
          ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text('Transaksi yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(transactionListProvider.notifier)
                  .deleteTransaction(transaction.id);
              if (context.mounted) {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Langkah 11: Buat RecurringListScreen

Buat file `lib/src/features/transactions/presentation/recurring_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recurring_rule.dart';
import '../domain/transaction.dart';
import '../providers/transaction_providers.dart';
import 'add_recurring_rule_screen.dart';

class RecurringListScreen extends ConsumerWidget {
  const RecurringListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(recurringRuleListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Berulang')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddRecurringRuleScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat: $error'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(recurringRuleListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(
              child: Text('Belum ada aturan transaksi berulang.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: rules.length,
            itemBuilder: (context, index) => _RecurringRuleTile(
              rule: rules[index],
              onDelete: () async {
                await ref
                    .read(recurringRuleListProvider.notifier)
                    .deleteRecurringRule(rules[index].id);
              },
            ),
          );
        },
      ),
    );
  }
}

class _RecurringRuleTile extends StatelessWidget {
  const _RecurringRuleTile({required this.rule, required this.onDelete});

  final RecurringRule rule;
  final VoidCallback onDelete;

  String _frequencyLabel(RecurringFrequency freq) {
    switch (freq) {
      case RecurringFrequency.daily:
        return 'Harian';
      case RecurringFrequency.weekly:
        return 'Mingguan';
      case RecurringFrequency.monthly:
        return 'Bulanan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = rule.type == TransactionType.expense;
    final color = isExpense ? Colors.red : Colors.green;
    final prefix = isExpense ? '-' : '+';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
            size: 20,
          ),
        ),
        title: Text(rule.note ?? 'Transaksi Berulang'),
        subtitle: Text(
          '${_frequencyLabel(rule.frequency)} • ${rule.nextRunDate}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$prefix Rp ${rule.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Aturan?'),
                    content: const Text('Aturan transaksi berulang akan dihapus.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onDelete();
                        },
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Langkah 12: Buat AddRecurringRuleScreen

Buat file `lib/src/features/transactions/presentation/add_recurring_rule_screen.dart`:

```dart
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

    await ref.read(recurringRuleListProvider.notifier).addRecurringRule(
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Nominal',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Wajib diisi';
                  if ((double.tryParse(v) ?? 0) <= 0) return 'Harus lebih dari 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RecurringFrequency>(
                value: _frequency,
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
                  value: _selectedWalletId,
                  decoration: const InputDecoration(
                    labelText: 'Dompet',
                    border: OutlineInputBorder(),
                  ),
                  items: wallets
                      .map((w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          ))
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
                      .where((c) =>
                          c.type.name == _type.name)
                      .toList();
                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tanpa Kategori'),
                      ),
                      ...filtered.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          )),
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
              FilledButton(
                onPressed: _submit,
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Langkah 13: Edit main.dart

Buka file `lib/main.dart` dan tambahkan 2 baris import serta 3 baris kode untuk menjalankan `RecurringChecker` saat aplikasi dimulai:

**Tambahkan import:**
```dart
import "package:finance_tracker/src/core/database/turso_client.dart";
import "package:finance_tracker/src/features/transactions/data/recurring_checker.dart";
```

**Tambahkan di dalam fungsi `main()`, setelah `await initDatabase();`:**
```dart
final recurringChecker = RecurringChecker(TursoClient());
await recurringChecker.checkAndRunDueTransactions();
```

---

## Langkah 14: Jalankan Code Generator

Setelah semua file dibuat, jalankan perintah berikut di terminal dari root project:

```bash
dart run build_runner build
```

Perintah ini akan menghasilkan file `.freezed.dart` dan `.g.dart` untuk model dan provider.

---

## Langkah 15: Verifikasi

Jalankan untuk memastikan tidak ada error:

```bash
flutter analyze
```

Harusnya hanya muncul info-level warnings (deprecated `value` pada DropdownButtonFormField), bukan error.

---

## Catatan Penting

1. **Jangan pakai `StateProvider`** - flutter_riverpod 3.2.1 tidak memiliki `StateProvider`. Gunakan `NotifierProvider` dengan class `Notifier`.
2. **Import `TransactionType` di `recurring_rule.dart`** - Harus import dari `transaction.dart` karena `TransactionType` didefinisikan di sana.
3. **Import `TransactionType` di `recurring_repository.dart`** - Harus import dari `transaction.dart`.
4. **Filter kategori vs transaksi** - Gunakan `c.type.name == _type.name` karena `CategoryType` dan `TransactionType` adalah enum terpisah meskipun nilainya sama.
5. **`copyWith` walletId** - Saat edit transaksi, gunakan `_selectedWalletId ?? widget.transaction!.walletId` karena `walletId` wajib non-null.
