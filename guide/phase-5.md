# Fase 5: Dasbor Cash Flow, Grafik Visualisasi, & Laporan Ekspor

Panduan langkah demi langkah untuk menerapkan Fase 5 pada aplikasi finance_tracker.

---

## Langkah 1: Tambahkan Dependensi Baru

Buka file `finance_tracker/pubspec.yaml` dan tambahkan 6 package baru di bagian `dependencies:` (setelah baris `http: ^1.2.0`):

```yaml
  fl_chart: ^1.2.0
  csv: ^8.0.0
  pdf: ^3.13.0
  printing: ^5.15.0
  path_provider: ^2.1.6
  share_plus: ^13.3.0
```

Lalu jalankan perintah berikut di terminal (di dalam folder `finance_tracker`):

```bash
flutter pub get
```

---

## Langkah 2: Buat Struktur Folder Dashboard

Buat folder-folder berikut di dalam `lib/src/features/`:

```
dashboard/
  domain/
  data/
  providers/
  presentation/
    widgets/
```

**Cara cepat:** Jalankan perintah berikut di terminal (di dalam folder `finance_tracker`):

```bash
mkdir -p lib/src/features/dashboard/domain
mkdir -p lib/src/features/dashboard/data
mkdir -p lib/src/features/dashboard/providers
mkdir -p lib/src/features/dashboard/presentation/widgets
```

---

## Langkah 3: Buat Model DashboardSummary

Buat file baru: `lib/src/features/dashboard/domain/dashboard_summary.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_summary.freezed.dart';
part 'dashboard_summary.g.dart';

/// Menyimpan total saldo dari semua dompet, plus pemasukan dan pengeluaran bulan ini.
@freezed
abstract class DashboardSummary with _$DashboardSummary {
  const factory DashboardSummary({
    required double totalBalance,
    required double monthlyIncome,
    required double monthlyExpense,
  }) = _DashboardSummary;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      _$DashboardSummaryFromJson(json);
}

/// Satu titik data cash flow harian untuk grafik garis.
@freezed
abstract class DailyCashFlow with _$DailyCashFlow {
  const factory DailyCashFlow({
    required String date,
    required double income,
    required double expense,
  }) = _DailyCashFlow;

  factory DailyCashFlow.fromJson(Map<String, dynamic> json) =>
      _$DailyCashFlowFromJson(json);
}

/// Distribusi pengeluaran per kategori untuk grafik pie.
@freezed
abstract class CategoryExpenseSummary with _$CategoryExpenseSummary {
  const factory CategoryExpenseSummary({
    required String categoryName,
    required String? categoryColor,
    required double total,
  }) = _CategoryExpenseSummary;

  factory CategoryExpenseSummary.fromJson(Map<String, dynamic> json) =>
      _$CategoryExpenseSummaryFromJson(json);
}
```

---

## Langkah 4: Buat DashboardRepository

Buat file baru: `lib/src/features/dashboard/data/dashboard_repository.dart`

```dart
import '../../../core/database/turso_client.dart';
import '../domain/dashboard_summary.dart';

/// Repository yang berisi query SQL untuk mengambil data ringkasan dashboard.
class DashboardRepository {
  DashboardRepository(this._client);

  final TursoClient _client;

  /// Menghitung total saldo dari semua dompet.
  Future<double> getTotalBalance() async {
    final rows = await _client.query(
      'SELECT COALESCE(SUM(balance), 0) AS total FROM wallets',
    );
    return (rows.first['total'] as num).toDouble();
  }

  /// Menghitung total pemasukan di bulan berjalan (format YYYY-MM).
  Future<double> getMonthlyIncome(String monthYear) async {
    final rows = await _client.query(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE type = 'income'
        AND strftime('%Y-%m', transaction_date) = ?
      ''',
      args: [monthYear],
    );
    return (rows.first['total'] as num).toDouble();
  }

  /// Menghitung total pengeluaran di bulan berjalan (format YYYY-MM).
  Future<double> getMonthlyExpense(String monthYear) async {
    final rows = await _client.query(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE type = 'expense'
        AND strftime('%Y-%m', transaction_date) = ?
      ''',
      args: [monthYear],
    );
    return (rows.first['total'] as num).toDouble();
  }

  /// Mengambil data cash flow harian untuk grafik garis.
  Future<List<DailyCashFlow>> getDailyCashFlow(String monthYear) async {
    final rows = await _client.query(
      '''
      SELECT
        transaction_date AS date,
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) AS income,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS expense
      FROM transactions
      WHERE strftime('%Y-%m', transaction_date) = ?
      GROUP BY transaction_date
      ORDER BY transaction_date ASC
      ''',
      args: [monthYear],
    );

    return rows
        .map(
          (row) => DailyCashFlow(
            date: row['date'] as String,
            income: (row['income'] as num).toDouble(),
            expense: (row['expense'] as num).toDouble(),
          ),
        )
        .toList();
  }

  /// Mengambil distribusi pengeluaran per kategori untuk grafik pie.
  Future<List<CategoryExpenseSummary>> getCategoryExpenses(
    String monthYear,
  ) async {
    final rows = await _client.query(
      '''
      SELECT
        c.name AS category_name,
        c.color AS category_color,
        SUM(t.amount) AS total
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.type = 'expense'
        AND strftime('%Y-%m', t.transaction_date) = ?
      GROUP BY t.category_id
      ORDER BY total DESC
      ''',
      args: [monthYear],
    );

    return rows
        .map(
          (row) => CategoryExpenseSummary(
            categoryName: row['category_name'] as String? ?? 'Tanpa Kategori',
            categoryColor: row['category_color'] as String?,
            total: (row['total'] as num).toDouble(),
          ),
        )
        .toList();
  }

  /// Mengambil ringkasan dashboard lengkap.
  Future<DashboardSummary> getDashboardSummary(String monthYear) async {
    final totalBalance = await getTotalBalance();
    final monthlyIncome = await getMonthlyIncome(monthYear);
    final monthlyExpense = await getMonthlyExpense(monthYear);

    return DashboardSummary(
      totalBalance: totalBalance,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
    );
  }
}
```

---

## Langkah 5: Buat Provider Dashboard

Buat file baru: `lib/src/features/dashboard/providers/dashboard_providers.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/turso_client_provider.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

part 'dashboard_providers.g.dart';

/// Provider untuk DashboardRepository.
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(tursoClientProvider));
});

/// Notifier untuk data ringkasan dashboard (total saldo, pemasukan, pengeluaran).
@Riverpod(keepAlive: true)
class DashboardSummaryNotifier extends _$DashboardSummaryNotifier {
  @override
  Future<DashboardSummary> build() async {
    final now = DateTime.now();
    final monthYear =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return ref.read(dashboardRepositoryProvider).getDashboardSummary(monthYear);
  }
}

/// Notifier untuk data cash flow harian (grafik garis).
@Riverpod(keepAlive: true)
class DailyCashFlowNotifier extends _$DailyCashFlowNotifier {
  @override
  Future<List<DailyCashFlow>> build() async {
    final now = DateTime.now();
    final monthYear =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return ref.read(dashboardRepositoryProvider).getDailyCashFlow(monthYear);
  }
}

/// Notifier untuk distribusi pengeluaran per kategori (grafik pie).
@Riverpod(keepAlive: true)
class CategoryExpenseNotifier extends _$CategoryExpenseNotifier {
  @override
  Future<List<CategoryExpenseSummary>> build() async {
    final now = DateTime.now();
    final monthYear =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return ref
        .read(dashboardRepositoryProvider)
        .getCategoryExpenses(monthYear);
  }
}
```

---

## Langkah 6: Buat Widget Grafik Garis (CashFlowLineChart)

Buat file baru: `lib/src/features/dashboard/presentation/widgets/cash_flow_line_chart.dart`

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/dashboard_summary.dart';

/// Grafik garis yang menampilkan tren pemasukan vs pengeluaran harian.
class CashFlowLineChart extends StatelessWidget {
  const CashFlowLineChart({super.key, required this.data});

  /// Data harian cash flow yang akan ditampilkan di grafik.
  final List<DailyCashFlow> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Belum ada data cash flow')),
      );
    }

    // Membuat titik-titik data untuk garis pemasukan
    final incomeSpots = <FlSpot>[];
    // Membuat titik-titik data untuk garis pengeluaran
    final expenseSpots = <FlSpot>[];

    for (var i = 0; i < data.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), data[i].income));
      expenseSpots.add(FlSpot(i.toDouble(), data[i].expense));
    }

    // Mencari nilai maksimum untuk menentukan batas sumbu Y
    final maxY = [...incomeSpots, ...expenseSpots]
        .map((s) => s.y)
        .fold(0.0, (a, b) => a > b ? a : b);

    // Membuat label tanggal pendek (contoh: "1", "5", "10")
    final bottomLabels = <int, String>{};
    for (var i = 0; i < data.length; i++) {
      final day = data[i].date.length >= 10
          ? data[i].date.substring(8, 10)
          : data[i].date;
      // Hanya tampilkan label setiap 5 hari atau data pertama/terakhir
      if (i == 0 || i == data.length - 1 || i % 5 == 0) {
        bottomLabels[i] = day;
      }
    }

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 12,
          right: 24,
          top: 16,
          bottom: 4,
        ),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final label = bottomLabels[value.toInt()];
                    if (label == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (data.length - 1).toDouble(),
            minY: 0,
            maxY: maxY > 0 ? maxY * 1.2 : 10,
            lineBarsData: [
              // Garis pemasukan (hijau)
              LineChartBarData(
                spots: incomeSpots,
                isCurved: true,
                color: Colors.green,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.green.withValues(alpha: 0.1),
                ),
              ),
              // Garis pengeluaran (merah)
              LineChartBarData(
                spots: expenseSpots,
                isCurved: true,
                color: Colors.red,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.red.withValues(alpha: 0.1),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final isIncome = spot.barIndex == 0;
                    final label = isIncome ? 'Pemasukan' : 'Pengeluaran';
                    return LineTooltipItem(
                      '$label\nRp ${spot.y.toStringAsFixed(0)}',
                      TextStyle(
                        color: isIncome ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## Langkah 7: Buat Widget Grafik Pie (CategoryExpensePieChart)

Buat file baru: `lib/src/features/dashboard/presentation/widgets/category_expense_pie_chart.dart`

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/color_utils.dart';
import '../../domain/dashboard_summary.dart';

/// Grafik pie/donat yang menampilkan distribusi pengeluaran per kategori.
class CategoryExpensePieChart extends StatelessWidget {
  const CategoryExpensePieChart({super.key, required this.data});

  /// Data distribusi pengeluaran per kategori.
  final List<CategoryExpenseSummary> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Belum ada data pengeluaran')),
      );
    }

    // Menghitung total pengeluaran untuk menghitung persentase
    final totalExpense =
        data.fold(0.0, (sum, item) => sum + item.total);

    // Daftar warna untuk kategori yang tidak memiliki warna sendiri
    final fallbackColors = [
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];

    return SizedBox(
      height: 220,
      child: Row(
        children: [
          // Grafik donat di sebelah kiri
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: List.generate(data.length, (index) {
                  final item = data[index];
                  final color = item.categoryColor != null
                      ? colorFromHex(item.categoryColor)
                      : fallbackColors[index % fallbackColors.length];
                  final percent = totalExpense > 0
                      ? (item.total / totalExpense * 100)
                      : 0.0;

                  return PieChartSectionData(
                    value: item.total,
                    color: color,
                    radius: 40,
                    title: percent >= 5
                        ? '${percent.toStringAsFixed(0)}%'
                        : '',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Daftar legenda di sebelah kanan
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(data.length, (index) {
                final item = data[index];
                final color = item.categoryColor != null
                    ? colorFromHex(item.categoryColor)
                    : fallbackColors[index % fallbackColors.length];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.categoryName,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Langkah 8: Buat Halaman Dashboard

Buat file baru: `lib/src/features/dashboard/presentation/dashboard_screen.dart`

```dart
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

/// Halaman utama dashboard yang menampilkan ringkasan keuangan,
/// grafik cash flow, grafik pie pengeluaran, aksi cepat, dan transaksi terakhir.
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
          // Tombol untuk membuka halaman ekspor laporan
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
          // Refresh semua data dashboard
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(dailyCashFlowProvider);
          ref.invalidate(categoryExpenseProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Bagian Kartu Ringkasan Saldo ---
            summaryAsync.when(
              loading: () => const _SummaryCardLoading(),
              error: (error, _) => _SummaryCardError(error: '$error'),
              data: (summary) => _SummaryCard(summary: summary),
            ),
            const SizedBox(height: 16),

            // --- Bagian Grafik Cash Flow ---
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

            // --- Bagian Grafik Pie Pengeluaran ---
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

            // --- Bagian Aksi Cepat ---
            _SectionTitle(title: 'Aksi Cepat'),
            const SizedBox(height: 8),
            _QuickActions(),
            const SizedBox(height: 16),

            // --- Bagian Transaksi Terakhir ---
            _SectionTitle(title: 'Transaksi Terakhir'),
            const SizedBox(height: 8),
            _RecentTransactions(),
          ],
        ),
      ),
    );
  }
}

/// Judul section yang konsisten di seluruh dashboard.
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

/// Kartu ringkasan yang menampilkan total saldo, pemasukan, dan pengeluaran bulan ini.
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrency(summary.totalBalance),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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

/// Item ringkasan kecil (pemasukan/pengeluaran) di dalam kartu ringkasan.
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

/// Tampilan loading untuk kartu ringkasan.
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

/// Tampilan error untuk kartu ringkasan.
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

/// Tombol aksi cepat untuk navigasi ke fitur utama.
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
                MaterialPageRoute(
                  builder: (_) => const AddTransactionScreen(),
                ),
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

/// Kartu aksi cepat individu.
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

/// Menampilkan 5 transaksi terakhir.
class _RecentTransactions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mengambil semua transaksi dari provider yang sudah ada
    final transactionsAsync = ref.watch(transactionListProvider);

    return transactionsAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 80,
        child: Center(child: Text('Gagal memuat: $e')),
      ),
      data: (transactions) {
        // Mengambil 5 transaksi terbaru
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
```

---

## Langkah 9: Buat Struktur Folder Export

Buat folder-folder berikut di dalam `lib/src/features/`:

```
export/
  data/
  presentation/
```

**Cara cepat:** Jalankan perintah berikut di terminal (di dalam folder `finance_tracker`):

```bash
mkdir -p lib/src/features/export/data
mkdir -p lib/src/features/export/presentation
```

---

## Langkah 10: Buat CsvExporterService

Buat file baru: `lib/src/features/export/data/csv_exporter_service.dart`

```dart
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../../transactions/domain/transaction.dart';

/// Service untuk mengubah riwayat transaksi menjadi file CSV.
class CsvExporterService {
  /// Mengubah daftar transaksi menjadi string CSV.
  String transactionsToCsv(List<Transaction> transactions) {
    // Header kolom CSV
    final rows = <List<dynamic>>[
      ['Tanggal', 'Jenis', 'Jumlah', 'Catatan'],
    ];

    // Menambahkan baris data untuk setiap transaksi
    for (final t in transactions) {
      rows.add([
        t.transactionDate,
        t.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran',
        t.amount,
        t.note ?? '',
      ]);
    }

    // Mengubah list of rows menjadi string CSV
    final csv = Csv();
    return csv.encode(rows);
  }

  /// Menyimpan string CSV ke file dan mengembalikan file tersebut.
  Future<File> saveCsvToFile(String csvString, String fileName) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString);
    return file;
  }
}
```

---

## Langkah 11: Buat PdfReportGeneratorService

Buat file baru: `lib/src/features/export/data/pdf_report_generator_service.dart`

```dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../transactions/domain/transaction.dart';

/// Service untuk membuat laporan PDF dari riwayat transaksi.
class PdfReportGeneratorService {
  /// Membuat dokumen PDF berisi laporan transaksi.
  Future<pw.Document> generateReport({
    required String title,
    required List<Transaction> transactions,
    required String monthYear,
  }) async {
    final pdf = pw.Document();

    // Menghitung total pemasukan dan pengeluaran
    var totalIncome = 0.0;
    var totalExpense = 0.0;
    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Header(
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ),
        footer: (context) => pw.Footer(
          trailing: pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
          ),
        ),
        build: (context) => [
          pw.Text(
            'Periode: $monthYear',
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 16),

          // Ringkasan singkat
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Total Pemasukan', totalIncome),
                _summaryItem('Total Pengeluaran', totalExpense),
                _summaryItem('Selisih', totalIncome - totalExpense),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Tabel transaksi
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerLeft,
            },
            headerAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerLeft,
            },
            headers: ['Tanggal', 'Jenis', 'Jumlah', 'Catatan'],
            data: transactions
                .map(
                  (t) => [
                    t.transactionDate,
                    t.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran',
                    _formatAmount(t.amount),
                    t.note ?? '',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Menyimpan PDF ke file.
  Future<File> savePdfToFile(pw.Document pdf, String fileName) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Membuat widget ringkasan untuk PDF.
  pw.Widget _summaryItem(String label, double amount) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _formatAmount(amount),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  /// Memformat angka menjadi format mata uang Rupiah.
  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
    }
    return 'Rp ${buffer.toString()}';
  }
}
```

---

## Langkah 12: Buat Halaman ExportReportScreen

Buat file baru: `lib/src/features/export/presentation/export_report_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../transactions/domain/transaction.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../data/csv_exporter_service.dart';
import '../data/pdf_report_generator_service.dart';

/// Halaman untuk mengekspor laporan transaksi ke CSV atau PDF.
class ExportReportScreen extends ConsumerStatefulWidget {
  const ExportReportScreen({super.key});

  @override
  ConsumerState<ExportReportScreen> createState() => _ExportReportScreenState();
}

class _ExportReportScreenState extends ConsumerState<ExportReportScreen> {
  late int _selectedYear;
  late int _selectedMonth;
  bool _isExporting = false;

  static const _monthNames = [
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  String get _monthYear =>
      '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

  Future<List<Transaction>> _getFilteredTransactions() async {
    final repo = ref.read(transactionRepositoryProvider);
    final monthStr = _selectedMonth.toString().padLeft(2, '0');
    final startDate = '$_selectedYear-$monthStr-01';
    final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final endDate = '$_selectedYear-$monthStr-$lastDay';

    return repo.getTransactions(startDate: startDate, endDate: endDate);
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);

    try {
      final transactions = await _getFilteredTransactions();
      final csvService = CsvExporterService();
      final csvString = csvService.transactionsToCsv(transactions);
      final fileName = 'transaksi_$_monthYear.csv';
      final file = await csvService.saveCsvToFile(csvString, fileName);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          title: 'Laporan Transaksi $_monthYear',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil mengekspor CSV')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);

    try {
      final transactions = await _getFilteredTransactions();
      final pdfService = PdfReportGeneratorService();
      final pdf = await pdfService.generateReport(
        title: 'Laporan Keuangan',
        transactions: transactions,
        monthYear: _monthYear,
      );
      final fileName = 'laporan_$_monthYear.pdf';
      final file = await pdfService.savePdfToFile(pdf, fileName);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          title: 'Laporan Keuangan $_monthYear',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil mengekspor PDF')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ekspor Laporan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Periode Laporan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'Tahun',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(10, (i) {
                              final year = DateTime.now().year - 5 + i;
                              return DropdownMenuItem(
                                value: year,
                                child: Text('$year'),
                              );
                            }),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedYear = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedMonth,
                            decoration: const InputDecoration(
                              labelText: 'Bulan',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(12, (i) {
                              return DropdownMenuItem(
                                value: i + 1,
                                child: Text(_monthNames[i + 1]),
                              );
                            }),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedMonth = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportCsv,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.table_chart),
              label: const Text('Download CSV'),
            ),
            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: _isExporting ? null : _exportPdf,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: const Text('Download PDF'),
            ),

            const SizedBox(height: 24),

            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pilih periode laporan, lalu ketuk tombol di atas untuk mengekspor dan membagikan file.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Langkah 13: Update main.dart

Buka file `lib/main.dart` dan lakukan 2 perubahan:

**Perubahan 1:** Ganti import `wallet_list_screen.dart` menjadi `dashboard_screen.dart`:

```dart
// GANTI baris ini:
import 'package:finance_tracker/src/features/wallets/presentation/wallet_list_screen.dart';

// MENJADI:
import 'package:finance_tracker/src/features/dashboard/presentation/dashboard_screen.dart';
```

**Perubahan 2:** Ganti `home` dari `WalletListScreen` menjadi `DashboardScreen`:

```dart
// GANTI baris ini:
home: const WalletListScreen(),

// MENJADI:
home: const DashboardScreen(),
```

---

## Langkah 14: Jalankan Code Generator

Jalankan perintah berikut di terminal (di dalam folder `finance_tracker`) untuk menghasilkan file kode yang diperlukan:

```bash
dart run build_runner build
```

Tunggu hingga selesai (biasanya 30-60 detik).

---

## Langkah 15: Verifikasi

Jalankan perintah berikut untuk memastikan tidak ada error:

```bash
flutter analyze lib/
```

Jika hasilnya `No issues found!`, maka Fase 5 sudah berhasil diterapkan.

---

## Struktur File yang Dihasilkan

Setelah menyelesaikan semua langkah, struktur folder baru akan seperti ini:

```
lib/src/features/dashboard/
  domain/
    dashboard_summary.dart
    dashboard_summary.freezed.dart    (otomatis)
    dashboard_summary.g.dart          (otomatis)
  data/
    dashboard_repository.dart
  providers/
    dashboard_providers.dart
    dashboard_providers.g.dart        (otomatis)
  presentation/
    dashboard_screen.dart
    widgets/
      cash_flow_line_chart.dart
      category_expense_pie_chart.dart

lib/src/features/export/
  data/
    csv_exporter_service.dart
    pdf_report_generator_service.dart
  presentation/
    export_report_screen.dart
```

---

## Fitur yang Ditambahkan

1. **Dashboard Data Aggregator** - Query SQL untuk menghitung total saldo, pemasukan, dan pengeluaran bulan ini
2. **Grafik Cash Flow** - Grafik garis tren pemasukan vs pengeluaran harian menggunakan `fl_chart`
3. **Grafik Pie Kategori** - Grafik donat distribusi pengeluaran per kategori menggunakan `fl_chart`
4. **Dashboard Screen** - Halaman utama dengan kartu ringkasan, grafik, aksi cepat, dan transaksi terakhir
5. **CSV Export** - Service untuk mengekspor riwayat transaksi ke file CSV
6. **PDF Export** - Service untuk membuat laporan PDF dari riwayat transaksi
7. **Export Report Screen** - Halaman untuk memilih periode dan mengekspor laporan
