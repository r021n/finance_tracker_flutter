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
