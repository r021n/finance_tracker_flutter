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
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
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
                      .map(
                        (t) => _TransactionTile(
                          transaction: t,
                          onTap: () => _openDetail(context, t),
                        ),
                      )
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
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
      error: (_, __) => ListTile(title: Text(transaction.note ?? 'Transaksi')),
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
              style: TextStyle(fontWeight: FontWeight.bold, color: amountColor),
            ),
          ),
        );
      },
    );
  }
}
