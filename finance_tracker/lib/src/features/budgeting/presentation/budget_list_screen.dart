import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/budget_providers.dart";
import "set_budget_dialog.dart";
import "widgets/budget_card.dart";
import "widgets/budget_warning_banner.dart";

class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  List<String> _generateMonthOptions() {
    final now = DateTime.now();
    final months = <String>[];
    for (int i = -6; i <= 6; i++) {
      final date = DateTime(now.year, now.month + i);
      months.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }
    return months;
  }

  String _monthLabel(String monthYear) {
    final parts = monthYear.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    const monthNames = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${monthNames[month]} $year';
  }

  void _openSetBudgetDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const SetBudgetDialog(),
    );

    if (result != null) {
      await ref
          .read(budgetListProvider.notifier)
          .setBudget(
            categoryId: result['categoryId'] as String,
            amountLimit: result['amountLimit'] as double,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(budgetListProvider);
    final summaryAsync = ref.watch(budgetSummaryProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthOptions = _generateMonthOptions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anggaran'),
        actions: [
          IconButton(
            onPressed: () => _openSetBudgetDialog(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Anggaran',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: selectedMonth,
              decoration: const InputDecoration(
                labelText: 'Bulan',
                border: OutlineInputBorder(),
              ),
              items: monthOptions
                  .map(
                    (m) =>
                        DropdownMenuItem(value: m, child: Text(_monthLabel(m))),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(selectedMonthProvider.notifier).setMonth(v);
                }
              },
            ),
          ),
          summaryAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (summary) => Column(
              children: [
                if (summary.totalLimit > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _SummaryItem(
                              label: 'Total Anggaran',
                              value: summary.totalLimit,
                            ),
                            _SummaryItem(
                              label: 'Total Terpakai',
                              value: summary.totalSpent,
                              isWarning:
                                  summary.totalSpent > summary.totalLimit * 0.7,
                            ),
                            _SummaryItem(
                              label: 'Sisa',
                              value: summary.totalLimit - summary.totalSpent,
                              isWarning:
                                  summary.totalSpent > summary.totalLimit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                BudgetWarningBanner(
                  totalSpent: summary.totalSpent,
                  totalLimit: summary.totalLimit,
                ),
              ],
            ),
          ),
          Expanded(
            child: budgetAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Gagal memuat anggaran: $e'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(budgetListProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
              data: (budgets) {
                if (budgets.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text('Belum ada anggaran untuk bulan ini'),
                        SizedBox(height: 4),
                        Text(
                          'Ketuk tombol + untuk menambahkan anggaran',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(budgetListProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: budgets.length,
                    itemBuilder: (context, index) {
                      final item = budgets[index];
                      return BudgetCard(
                        item: item,
                        onDelete: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Anggaran?'),
                              content: Text(
                                'Hapus anggaran untuk ${item.categoryName}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await ref
                                .read(budgetListProvider.notifier)
                                .removeBudget(item.budget.id);
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final double value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? Colors.red : Colors.grey.shade800;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          _formatValue(value),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatValue(double amount) {
    final parts = amount.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
    }
    return 'Rp ${buffer.toString()}';
  }
}
