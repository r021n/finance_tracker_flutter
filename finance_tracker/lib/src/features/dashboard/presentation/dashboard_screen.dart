import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../transactions/presentation/add_transaction_screen.dart';
import '../../transactions/presentation/transaction_history_screen.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../../export/presentation/export_report_screen.dart';
import '../providers/dashboard_providers.dart';
import 'widgets/cash_flow_line_chart.dart';
import 'widgets/category_expense_pie_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final cashFlowAsync = ref.watch(dailyCashFlowProvider);
    final categoryExpenseAsync = ref.watch(categoryExpenseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dasbor Keuangan'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExportReportScreen()),
              );
            },
            icon: const Icon(Icons.download),
            tooltip: 'Ekspor Laporan',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(dailyCashFlowProvider);
          ref.invalidate(categoryExpenseProvider);
          await Future.wait([
            ref.read(dashboardSummaryProvider.future),
            ref.read(dailyCashFlowProvider.future),
            ref.read(categoryExpenseProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summaryAsync.when(
              loading: () => const _SummaryCardLoading(),
              error: (error, _) => _SummaryCardError(error: '$error'),
              data: (summary) => _SummaryCard(summary: summary),
            ),
            const SizedBox(height: 16),

            _SectionTitle(title: 'Cash Flow Bulan Ini'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: cashFlowAsync.when(
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SizedBox(
                    height: 200,
                    child: Center(child: Text('Gagal memuat grafik: $e')),
                  ),
                  data: (data) => CashFlowLineChart(data: data),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _SectionTitle(title: 'Pengeluaran per Kategori'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: categoryExpenseAsync.when(
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SizedBox(
                    height: 200,
                    child: Center(child: Text('Gagal memuat grafik: $e')),
                  ),
                  data: (data) => CategoryExpensePieChart(data: data),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _SectionTitle(title: 'Aksi Cepat'),
            const SizedBox(height: 8),
            _QuickActions(),
            const SizedBox(height: 16),

            _SectionTitle(title: 'Transaksi Terakhir'),
            const SizedBox(height: 8),
            _RecentTransactions(),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final dynamic summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Saldo',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrency(summary.totalBalance),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryMini(
                  label: 'Pemasukan',
                  value: summary.monthlyIncome,
                  color: Colors.green,
                  icon: Icons.arrow_downward,
                ),
                _SummaryMini(
                  label: 'Pengeluaran',
                  value: summary.monthlyExpense,
                  color: Colors.red,
                  icon: Icons.arrow_upward,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMini extends StatelessWidget {
  const _SummaryMini({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          formatCurrency(value),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SummaryCardLoading extends StatelessWidget {
  const _SummaryCardLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _SummaryCardError extends StatelessWidget {
  const _SummaryCardError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat data: $error'),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.add_circle,
            label: 'Tambah\nTransaksi',
            color: Colors.green,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.history,
            label: 'Riwayat\nTransaksi',
            color: Colors.blue,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TransactionHistoryScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionListProvider);

    return transactionsAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          SizedBox(height: 80, child: Center(child: Text('Gagal memuat: $e'))),
      data: (transactions) {
        final recent = transactions.take(5).toList();

        if (recent.isEmpty) {
          return const SizedBox(
            height: 80,
            child: Center(child: Text('Belum ada transaksi')),
          );
        }

        return Column(
          children: recent.map((t) {
            final isExpense = t.type.name == 'expense';
            final amountColor = isExpense ? Colors.red : Colors.green;
            final prefix = isExpense ? '-' : '+';

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: amountColor.withValues(alpha: 0.1),
                  child: Icon(
                    isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                    color: amountColor,
                    size: 18,
                  ),
                ),
                title: Text(
                  t.note ?? 'Transaksi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  t.transactionDate.length >= 10
                      ? t.transactionDate.substring(0, 10)
                      : t.transactionDate,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '$prefix${formatCurrency(t.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
