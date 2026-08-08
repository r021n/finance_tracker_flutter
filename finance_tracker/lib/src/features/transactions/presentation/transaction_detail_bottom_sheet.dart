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
                        builder: (_) =>
                            AddTransactionScreen(transaction: transaction),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit"),
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
      final wallet = wallets
          .where((w) => w.id == transaction.walletId)
          .firstOrNull;
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
