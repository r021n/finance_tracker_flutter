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
            MaterialPageRoute(builder: (_) => const AddRecurringRuleScreen()),
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
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Aturan?'),
                    content: const Text(
                      'Aturan transaksi berulang akan dihapus.',
                    ),
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
