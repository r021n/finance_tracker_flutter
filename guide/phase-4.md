# Panduan Fase 4: Penganggaran (Budgeting) & Target Tabungan (Savings Goals)

Panduan ini berisi langkah-langkah pasti untuk mengerjakan Fase 4 aplikasi Finance Tracker. Ikuti setiap langkah secara berurutan.

---

## Persiapan: Struktur Folder

Buat folder-folder berikut di dalam `lib/src/features/`:

```
budgeting/
  domain/
  data/
  providers/
  presentation/
    widgets/

savings/
  domain/
  data/
  providers/
  presentation/
    widgets/
```

Cara membuat (jalankan di terminal dari folder `finance_tracker`):
```bash
# Budgeting
mkdir -p lib/src/features/budgeting/domain
mkdir -p lib/src/features/budgeting/data
mkdir -p lib/src/features/budgeting/providers
mkdir -p lib/src/features/budgeting/presentation/widgets

# Savings
mkdir -p lib/src/features/savings/domain
mkdir -p lib/src/features/savings/data
mkdir -p lib/src/features/savings/providers
mkdir -p lib/src/features/savings/presentation/widgets
```

---

## Langkah 1: Model Budget (Domain)

**Buat file:** `lib/src/features/budgeting/domain/budget.dart`

```dart
import "package:freezed_annotation/freezed_annotation.dart";

part "budget.freezed.dart";
part "budget.g.dart";

// Model data anggaran yang tersimpan di database.
// Menyimpan batas pengeluaran untuk satu kategori dalam satu bulan tertentu.
@freezed
abstract class Budget with _$Budget {
  const Budget._();

  const factory Budget({
    required String id,
    required String categoryId,
    required double amountLimit,
    required String monthYear, // format YYYY-MM
    String? createdAt,
  }) = _Budget;

  factory Budget.fromJson(Map<String, dynamic> json) => _$BudgetFromJson(json);
}

// Model anggaran yang sudah dilengkapi dengan data pengeluaran aktual.
// Digunakan di UI untuk menampilkan progres penggunaan anggaran.
@freezed
abstract class BudgetWithProgress with _$BudgetWithProgress {
  const BudgetWithProgress._();

  const factory BudgetWithProgress({
    required Budget budget,
    required String categoryName,
    String? categoryIcon,
    String? categoryColor,
    required double spent, // total pengeluaran aktual di kategori ini
  }) = _BudgetWithProgress;

  // Persentase penggunaan anggaran (0.0 - 1.0+, bisa lebih dari 1.0 jika overbudget)
  double get usagePercent =>
      budget.amountLimit > 0 ? spent / budget.amountLimit : 0.0;

  // Sisa anggaran yang masih tersedia (bisa negatif jika overbudget)
  double get remaining => budget.amountLimit - spent;
}
```

---

## Langkah 2: Budget Repository (Data Layer)

**Buat file:** `lib/src/features/budgeting/data/budget_repository.dart`

```dart
import "package:uuid/uuid.dart";

import "../../../core/database/turso_client.dart";
import "../domain/budget.dart";

const _uuid = Uuid();

class BudgetRepository {
  BudgetRepository(this._client);

  final TursoClient _client;

  // Mengambil semua anggaran untuk bulan tertentu beserta jumlah pengeluaran aktualnya.
  // Parameter [monthYear] format: YYYY-MM (contoh: "2026-08")
  Future<List<BudgetWithProgress>> getBudgetsWithProgress(
    String monthYear,
  ) async {
    // Query gabungan: ambil data budget + jumlah total pengeluaran per kategori di bulan itu
    final rows = await _client.query(
      '''
      SELECT
        b.id            AS budget_id,
        b.category_id,
        b.amount_limit,
        b.month_year,
        b.created_at    AS budget_created_at,
        c.name          AS category_name,
        c.icon          AS category_icon,
        c.color         AS category_color,
        COALESCE(SUM(t.amount), 0) AS spent
      FROM budgets b
      JOIN categories c ON c.id = b.category_id
      LEFT JOIN transactions t
        ON t.category_id = b.category_id
        AND t.type = 'expense'
        AND strftime('%Y-%m', t.transaction_date) = b.month_year
      WHERE b.month_year = ?
      GROUP BY b.id
      ORDER BY c.name ASC
      ''',
      args: [monthYear],
    );

    return rows.map((row) {
      final budget = Budget(
        id: row['budget_id'] as String,
        categoryId: row['category_id'] as String,
        amountLimit: (row['amount_limit'] as num).toDouble(),
        monthYear: row['month_year'] as String,
        createdAt: row['budget_created_at'] as String?,
      );

      return BudgetWithProgress(
        budget: budget,
        categoryName: row['category_name'] as String,
        categoryIcon: row['category_icon'] as String?,
        categoryColor: row['category_color'] as String?,
        spent: (row['spent'] as num).toDouble(),
      );
    }).toList();
  }

  // Membuat anggaran baru untuk kategori di bulan tertentu.
  // Jika sudah ada anggaran untuk kategori+bulan yang sama, akan ditimpa.
  Future<Budget> setBudget({
    required String categoryId,
    required double amountLimit,
    required String monthYear,
  }) async {
    // Cek apakah sudah ada budget untuk kategori+bulan ini
    final existing = await _client.query(
      'SELECT id FROM budgets WHERE category_id = ? AND month_year = ?',
      args: [categoryId, monthYear],
    );

    if (existing.isNotEmpty) {
      // Update yang sudah ada
      final id = existing.first['id'] as String;
      await _client.execute(
        'UPDATE budgets SET amount_limit = ? WHERE id = ?',
        args: [amountLimit, id],
      );
      return Budget(
        id: id,
        categoryId: categoryId,
        amountLimit: amountLimit,
        monthYear: monthYear,
      );
    }

    // Buat baru
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();
    await _client.execute(
      '''
      INSERT INTO budgets (id, category_id, amount_limit, month_year, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      args: [id, categoryId, amountLimit, monthYear, now],
    );

    return Budget(
      id: id,
      categoryId: categoryId,
      amountLimit: amountLimit,
      monthYear: monthYear,
      createdAt: now,
    );
  }

  // Menghapus anggaran berdasarkan ID.
  Future<void> deleteBudget(String id) async {
    await _client.execute('DELETE FROM budgets WHERE id = ?', args: [id]);
  }

  // Mengambil total pengeluaran semua kategori di bulan tertentu.
  Future<double> getTotalSpent(String monthYear) async {
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

  // Mengambil total batas anggaran semua kategori di bulan tertentu.
  Future<double> getTotalBudgetLimit(String monthYear) async {
    final rows = await _client.query(
      'SELECT COALESCE(SUM(amount_limit), 0) AS total FROM budgets WHERE month_year = ?',
      args: [monthYear],
    );
    return (rows.first['total'] as num).toDouble();
  }
}
```

---

## Langkah 3: Budget Providers (State Management)

**Buat file:** `lib/src/features/budgeting/providers/budget_providers.dart`

```dart
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/database/turso_client_provider.dart";
import "../data/budget_repository.dart";
import "../domain/budget.dart";

part "budget_providers.g.dart";

// Provider untuk BudgetRepository, mengambil TursoClient dari provider global.
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(tursoClientProvider));
});

// Provider yang menyimpan bulan tahun yang sedang dilihat pengguna.
// Format: YYYY-MM (contoh: "2026-08")
// Menggunakan NotifierProvider untuk memungkinkan perubahan nilai dari UI.
final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, String>(SelectedMonthNotifier.new);

class SelectedMonthNotifier extends Notifier<String> {
  @override
  String build() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // Mengubah bulan yang dipilih.
  void setMonth(String monthYear) {
    state = monthYear;
  }
}

// Notifier untuk mengelola daftar anggaran beserta progresnya.
// Menggunakan AsyncNotifier karena data diambil dari database async.
@Riverpod(keepAlive: true)
class BudgetListNotifier extends _$BudgetListNotifier {
  @override
  Future<List<BudgetWithProgress>> build() async {
    final monthYear = ref.watch(selectedMonthProvider);
    return ref.watch(budgetRepositoryProvider).getBudgetsWithProgress(monthYear);
  }

  // Menetapkan atau memperbarui anggaran untuk kategori tertentu di bulan yang dipilih.
  Future<void> setBudget({
    required String categoryId,
    required double amountLimit,
  }) async {
    final monthYear = ref.read(selectedMonthProvider);
    await ref.read(budgetRepositoryProvider).setBudget(
      categoryId: categoryId,
      amountLimit: amountLimit,
      monthYear: monthYear,
    );
    ref.invalidateSelf();
  }

  // Menghapus anggaran berdasarkan ID.
  Future<void> removeBudget(String id) async {
    await ref.read(budgetRepositoryProvider).deleteBudget(id);
    ref.invalidateSelf();
  }
}

// Notifier untuk melacak total pengeluaran dan total batas anggaran di bulan yang dipilih.
@Riverpod(keepAlive: true)
class BudgetSummaryNotifier extends _$BudgetSummaryNotifier {
  @override
  Future<({double totalSpent, double totalLimit})> build() async {
    final monthYear = ref.watch(selectedMonthProvider);
    final repo = ref.watch(budgetRepositoryProvider);
    final totalSpent = await repo.getTotalSpent(monthYear);
    final totalLimit = await repo.getTotalBudgetLimit(monthYear);
    return (totalSpent: totalSpent, totalLimit: totalLimit);
  }
}
```

---

## Langkah 4: Widget BudgetProgressBar

**Buat file:** `lib/src/features/budgeting/presentation/widgets/budget_progress_bar.dart`

```dart
import "package:flutter/material.dart";

// Widget batang progres anggaran yang berubah warna berdasarkan persentase penggunaan.
// - Hijau: kurang dari 70% (aman)
// - Kuning: 70% - 90% (mendekati batas)
// - Merah: lebih dari 90% atau overbudget (melebihi batas)
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.progress, // 0.0 - 1.0+
    this.height = 8.0,
    this.color,
  });

  // Nilai progres (0.0 sampai 1.0 atau lebih jika overbudget).
  final double progress;

  // Tinggi bar progres.
  final double height;

  // Warna custom (opsional). Jika null, warna ditentukan otomatis berdasarkan progress.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? _getColor(progress);
    // Batasi progress antara 0.0 dan 1.0 untuk lebar visual
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                // Latar belakang bar (abu-abu terang)
                Container(
                  width: double.infinity,
                  color: Colors.grey.shade200,
                ),
                // Isi bar progres
                FractionallySizedBox(
                  widthFactor: clampedProgress,
                  child: Container(
                    color: barColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Label persentase
        Text(
          '${(progress * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: barColor,
          ),
        ),
      ],
    );
  }

  // Menentukan warna bar berdasarkan persentase penggunaan.
  Color _getColor(double percent) {
    if (percent > 0.9) return Colors.red;
    if (percent > 0.7) return Colors.orange;
    return Colors.green;
  }
}
```

---

## Langkah 5: Widget BudgetCard

**Buat file:** `lib/src/features/budgeting/presentation/widgets/budget_card.dart`

```dart
import "package:flutter/material.dart";

import "../../../../core/utils/color_utils.dart";
import "../../../../core/utils/currency_formatter.dart";
import "../../../../shared/constants/app_icons.dart";
import "../../domain/budget.dart";
import "budget_progress_bar.dart";

// Kartu yang menampilkan satu anggaran kategori beserta progresnya.
// Menampilkan nama kategori, ikon, batas anggaran, jumlah terpakai, dan bar progres.
class BudgetCard extends StatelessWidget {
  const BudgetCard({super.key, required this.item, this.onDelete});

  // Data anggaran beserta progres penggunaannya.
  final BudgetWithProgress item;

  // Callback saat tombol hapus ditekan (opsional).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(item.categoryColor);
    final isOverbudget = item.usagePercent > 1.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris atas: ikon, nama kategori, tombol hapus
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(iconFromName(item.categoryIcon), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.categoryName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Batas: ${formatCurrency(item.budget.amountLimit)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Hapus anggaran',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Bar progres
            BudgetProgressBar(progress: item.usagePercent),
            const SizedBox(height: 8),
            // Detail nominal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Terpakai: ${formatCurrency(item.spent)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isOverbudget ? Colors.red : Colors.grey.shade700,
                    fontWeight:
                        isOverbudget ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  isOverbudget
                      ? 'Over ${formatCurrency(item.spent - item.budget.amountLimit)}'
                      : 'Sisa: ${formatCurrency(item.remaining)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isOverbudget ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Langkah 6: Widget BudgetWarningBanner

**Buat file:** `lib/src/features/budgeting/presentation/widgets/budget_warning_banner.dart`

```dart
import "package:flutter/material.dart";

import "../../../../core/utils/currency_formatter.dart";

// Banner peringatan yang muncul ketika total pengeluaran mendekati atau melampaui
// total batas anggaran di bulan yang dipilih.
class BudgetWarningBanner extends StatelessWidget {
  const BudgetWarningBanner({
    super.key,
    required this.totalSpent,
    required this.totalLimit,
  });

  // Total pengeluaran di bulan ini.
  final double totalSpent;

  // Total batas anggaran di bulan ini.
  final double totalLimit;

  @override
  Widget build(BuildContext context) {
    // Jika tidak ada anggaran yang diset, jangan tampilkan apa-apa
    if (totalLimit <= 0) return const SizedBox.shrink();

    final percent = totalSpent / totalLimit;
    final isWarning = percent >= 0.7;
    final isOverbudget = percent >= 1.0;

    // Jika masih aman (kurang dari 70%), jangan tampilkan banner
    if (!isWarning) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverbudget
            ? Colors.red.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverbudget ? Colors.red.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOverbudget ? Icons.error : Icons.warning,
            color: isOverbudget ? Colors.red : Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverbudget
                      ? 'Anggaran Telah Terlampaui!'
                      : 'Hampir Melebihi Anggaran',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOverbudget ? Colors.red : Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOverbudget
                      ? 'Pengeluaran ${formatCurrency(totalSpent)} melebihi anggaran ${formatCurrency(totalLimit)}'
                      : 'Pengeluaran ${formatCurrency(totalSpent)} dari ${formatCurrency(totalLimit)} (${(percent * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Langkah 7: Dialog SetBudgetDialog

**Buat file:** `lib/src/features/budgeting/presentation/set_budget_dialog.dart`

```dart
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../categories/providers/category_providers.dart";

// Dialog untuk menetapkan atau mengubah batas anggaran per kategori.
// Pengguna memilih kategori dan memasukkan nominal batas anggaran.
class SetBudgetDialog extends ConsumerStatefulWidget {
  const SetBudgetDialog({super.key});

  @override
  ConsumerState<SetBudgetDialog> createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends ConsumerState<SetBudgetDialog> {
  String? _selectedCategoryId;
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori terlebih dahulu')),
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

    Navigator.of(context).pop({
      'categoryId': _selectedCategoryId!,
      'amountLimit': amount,
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);

    return AlertDialog(
      title: const Text('Atur Anggaran'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pilih kategori
            categoriesAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Gagal memuat kategori: $e'),
              data: (categories) {
                // Hanya tampilkan kategori pengeluaran
                final expenseCategories =
                    categories.where((c) => c.type.name == 'expense').toList();
                return DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: expenseCategories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            // Input nominal batas anggaran
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Batas Anggaran (Rp)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
```

---

## Langkah 8: Halaman BudgetListScreen

**Buat file:** `lib/src/features/budgeting/presentation/budget_list_screen.dart`

```dart
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/budget_providers.dart";
import "set_budget_dialog.dart";
import "widgets/budget_card.dart";
import "widgets/budget_warning_banner.dart";

// Halaman utama untuk menampilkan daftar anggaran bulanan per kategori.
// Menampilkan ringkasan total, peringatan jika mendekati batas, dan daftar kartu anggaran.
class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  // Menghasilkan daftar bulan yang bisa dipilih (6 bulan terakhir dan 6 bulan ke depan).
  List<String> _generateMonthOptions() {
    final now = DateTime.now();
    final months = <String>[];
    for (int i = -6; i <= 6; i++) {
      final date = DateTime(now.year, now.month + i);
      months.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }
    return months;
  }

  // Mengubah format YYYY-MM menjadi label yang mudah dibaca (contoh: "Agustus 2026").
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
      await ref.read(budgetListProvider.notifier).setBudget(
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
          // Tombol untuk menambah anggaran baru
          IconButton(
            onPressed: () => _openSetBudgetDialog(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Anggaran',
          ),
        ],
      ),
      body: Column(
        children: [
          // Pilih bulan
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
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(_monthLabel(m)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(selectedMonthProvider.notifier).setMonth(v);
                }
              },
            ),
          ),
          // Ringkasan total anggaran
          summaryAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (summary) => Column(
              children: [
                // Tampilkan ringkasan jika ada anggaran
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
                              isWarning: summary.totalSpent >
                                  summary.totalLimit * 0.7,
                            ),
                            _SummaryItem(
                              label: 'Sisa',
                              value: summary.totalLimit - summary.totalSpent,
                              isWarning: summary.totalSpent >
                                  summary.totalLimit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Banner peringatan jika mendekati/melebihi batas
                BudgetWarningBanner(
                  totalSpent: summary.totalSpent,
                  totalLimit: summary.totalLimit,
                ),
              ],
            ),
          ),
          // Daftar anggaran
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
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 48, color: Colors.grey),
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
                                  'Hapus anggaran untuk ${item.categoryName}?'),
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

// Widget kecil untuk menampilkan satu item ringkasan (label + nominal).
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
    // Format sederhana: Rp 1.000.000
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

## Langkah 9: Model SavingsGoal (Domain)

**Buat file:** `lib/src/features/savings/domain/savings_goal.dart`

```dart
import "package:freezed_annotation/freezed_annotation.dart";

part "savings_goal.freezed.dart";
part "savings_goal.g.dart";

// Model data target tabungan yang tersimpan di database.
// Menyimpan informasi tentang目标 tabungan pengguna.
@freezed
abstract class SavingsGoal with _$SavingsGoal {
  const SavingsGoal._();

  const factory SavingsGoal({
    required String id,
    required String title,
    required double targetAmount,
    @Default(0.0) double currentAmount,
    String? targetDate,
    String? createdAt,
  }) = _SavingsGoal;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) =>
      _$SavingsGoalFromJson(json);

  // Persentase progres tabungan (0.0 - 1.0)
  double get progressPercent =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  // Sisa dana yang perlu dikumpulkan
  double get remaining => targetAmount - currentAmount;
}
```

---

## Langkah 10: SavingsGoal Repository (Data Layer)

**Buat file:** `lib/src/features/savings/data/savings_goal_repository.dart`

```dart
import "package:uuid/uuid.dart";

import "../../../core/database/turso_client.dart";
import "../domain/savings_goal.dart";

const _uuid = Uuid();

class SavingsGoalRepository {
  SavingsGoalRepository(this._client);

  final TursoClient _client;

  // Mengambil semua target tabungan, diurutkan berdasarkan tanggal dibuat.
  Future<List<SavingsGoal>> getSavingsGoals() async {
    final rows = await _client.query(
      "SELECT * FROM savings_goals ORDER BY created_at ASC",
    );
    return rows.map(SavingsGoal.fromJson).toList();
  }

  // Membuat target tabungan baru.
  Future<SavingsGoal> createSavingsGoal({
    required String title,
    required double targetAmount,
    String? targetDate,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();

    await _client.execute(
      '''
      INSERT INTO savings_goals (id, title, target_amount, current_amount, target_date, created_at)
      VALUES (?, ?, ?, 0, ?, ?)
      ''',
      args: [id, title, targetAmount, targetDate, now],
    );

    return SavingsGoal(
      id: id,
      title: title,
      targetAmount: targetAmount,
      targetDate: targetDate,
      createdAt: now,
    );
  }

  // Memperbarui data target tabungan (judul, target nominal, tanggal target).
  Future<void> updateSavingsGoal(SavingsGoal goal) async {
    await _client.execute(
      '''
      UPDATE savings_goals
      SET title = ?, target_amount = ?, target_date = ?
      WHERE id = ?
      ''',
      args: [goal.title, goal.targetAmount, goal.targetDate, goal.id],
    );
  }

  // Menghapus target tabungan berdasarkan ID.
  Future<void> deleteSavingsGoal(String id) async {
    await _client.execute(
      "DELETE FROM savings_goals WHERE id = ?",
      args: [id],
    );
  }

  // Menambahkan dana ke target tabungan dari dompet tertentu.
  // Parameter [amount] harus positif untuk menambah tabungan.
  // Mengurangi saldo dompet dan menambah jumlah terkumpul di target tabungan.
  Future<void> deposit({
    required String goalId,
    required String walletId,
    required double amount,
  }) async {
    if (amount <= 0) return;

    // Kurangi saldo dompet
    await _client.execute(
      'UPDATE wallets SET balance = balance - ? WHERE id = ?',
      args: [amount, walletId],
    );

    // Tambah jumlah terkumpul di target tabungan
    await _client.execute(
      'UPDATE savings_goals SET current_amount = current_amount + ? WHERE id = ?',
      args: [amount, goalId],
    );
  }

  // Menarik dana dari target tabungan ke dompet tertentu.
  // Parameter [amount] harus positif untuk menarik tabungan.
  // Menambah saldo dompet dan mengurangi jumlah terkumpul di target tabungan.
  Future<void> withdraw({
    required String goalId,
    required String walletId,
    required double amount,
  }) async {
    if (amount <= 0) return;

    // Cek jumlah terkumpul saat ini
    final rows = await _client.query(
      'SELECT current_amount FROM savings_goals WHERE id = ?',
      args: [goalId],
    );
    if (rows.isEmpty) return;

    final currentAmount = (rows.first['current_amount'] as num).toDouble();
    final withdrawAmount = amount > currentAmount ? currentAmount : amount;

    // Tambah saldo dompet
    await _client.execute(
      'UPDATE wallets SET balance = balance + ? WHERE id = ?',
      args: [withdrawAmount, walletId],
    );

    // Kurangi jumlah terkumpul di target tabungan
    await _client.execute(
      'UPDATE savings_goals SET current_amount = current_amount - ? WHERE id = ?',
      args: [withdrawAmount, goalId],
    );
  }
}
```

---

## Langkah 11: SavingsGoal Providers (State Management)

**Buat file:** `lib/src/features/savings/providers/savings_goal_providers.dart`

```dart
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/database/turso_client_provider.dart";
import "../data/savings_goal_repository.dart";
import "../domain/savings_goal.dart";

part "savings_goal_providers.g.dart";

// Provider untuk SavingsGoalRepository, mengambil TursoClient dari provider global.
final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  return SavingsGoalRepository(ref.watch(tursoClientProvider));
});

// Notifier untuk mengelola daftar target tabungan.
@Riverpod(keepAlive: true)
class SavingsGoalListNotifier extends _$SavingsGoalListNotifier {
  @override
  Future<List<SavingsGoal>> build() async {
    return ref.watch(savingsGoalRepositoryProvider).getSavingsGoals();
  }

  // Membuat target tabungan baru.
  Future<void> addSavingsGoal({
    required String title,
    required double targetAmount,
    String? targetDate,
  }) async {
    final goal = await ref.read(savingsGoalRepositoryProvider).createSavingsGoal(
      title: title,
      targetAmount: targetAmount,
      targetDate: targetDate,
    );
    final current = await future;
    state = AsyncData([...current, goal]);
  }

  // Memperbarui data target tabungan.
  Future<void> editSavingsGoal(SavingsGoal goal) async {
    await ref.read(savingsGoalRepositoryProvider).updateSavingsGoal(goal);
    final current = await future;
    state = AsyncData([
      for (final g in current) g.id == goal.id ? goal : g,
    ]);
  }

  // Menghapus target tabungan.
  Future<void> removeSavingsGoal(String id) async {
    await ref.read(savingsGoalRepositoryProvider).deleteSavingsGoal(id);
    final current = await future;
    state = AsyncData([
      for (final g in current)
        if (g.id != id) g,
    ]);
  }

  // Menambahkan dana ke target tabungan dari dompet tertentu.
  Future<void> deposit({
    required String goalId,
    required String walletId,
    required double amount,
  }) async {
    await ref.read(savingsGoalRepositoryProvider).deposit(
      goalId: goalId,
      walletId: walletId,
      amount: amount,
    );
    ref.invalidateSelf();
  }

  // Menarik dana dari target tabungan ke dompet tertentu.
  Future<void> withdraw({
    required String goalId,
    required String walletId,
    required double amount,
  }) async {
    await ref.read(savingsGoalRepositoryProvider).withdraw(
      goalId: goalId,
      walletId: walletId,
      amount: amount,
    );
    ref.invalidateSelf();
  }
}
```

---

## Langkah 12: Widget SavingsGoalCard

**Buat file:** `lib/src/features/savings/presentation/widgets/savings_goal_card.dart`

```dart
import "package:flutter/material.dart";

import "../../../../core/utils/currency_formatter.dart";
import "../../domain/savings_goal.dart";

// Kartu yang menampilkan satu target tabungan beserta progresnya.
// Menampilkan ikon, judul, target nominal, jumlah terkumpul, dan persentase progres.
class SavingsGoalCard extends StatelessWidget {
  const SavingsGoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.onDelete,
  });

  // Data target tabungan.
  final SavingsGoal goal;

  // Callback saat kartu diketuk (opsional, untuk deposit/withdraw).
  final VoidCallback? onTap;

  // Callback saat tombol hapus ditekan (opsional).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isComplete = goal.progressPercent >= 1.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris atas: ikon, judul, tombol hapus
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isComplete
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.blue.withValues(alpha: 0.15),
                    child: Icon(
                      isComplete ? Icons.check_circle : Icons.savings,
                      color: isComplete ? Colors.green : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Target: ${formatCurrency(goal.targetAmount)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Hapus target',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Bar progres
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: goal.progressPercent,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? Colors.green : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Detail nominal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terkumpul: ${formatCurrency(goal.currentAmount)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isComplete ? Colors.green : Colors.blue,
                    ),
                  ),
                  Text(
                    '${(goal.progressPercent * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? Colors.green : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              // Tampilkan tanggal target jika ada
              if (goal.targetDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Target tanggal: ${goal.targetDate}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Langkah 13: Dialog DepositWithdrawGoalDialog

**Buat file:** `lib/src/features/savings/presentation/deposit_withdraw_goal_dialog.dart`

```dart
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../wallets/providers/wallet_providers.dart";

// Dialog untuk menambahkan atau menarik dana dari target tabungan.
// Pengguna memilih dompet sumber/tujuan dan memasukkan nominal yang akan ditransfer.
class DepositWithdrawGoalDialog extends ConsumerStatefulWidget {
  const DepositWithdrawGoalDialog({
    super.key,
    required this.goalTitle,
    required this.isDeposit, // true = setor, false = tarik
    required this.currentAmount,
  });

  // Judul target tabungan (untuk ditampilkan di dialog).
  final String goalTitle;

  // Apakah ini transaksi setoran (true) atau penarikan (false).
  final bool isDeposit;

  // Jumlah terkumpul saat ini (untuk membatasi jumlah penarikan).
  final double currentAmount;

  @override
  ConsumerState<DepositWithdrawGoalDialog> createState() =>
      _DepositWithdrawGoalDialogState();
}

class _DepositWithdrawGoalDialogState
    extends ConsumerState<DepositWithdrawGoalDialog> {
  String? _selectedWalletId;
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
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

    Navigator.of(context).pop({
      'walletId': _selectedWalletId!,
      'amount': amount,
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletListProvider);

    return AlertDialog(
      title: Text(widget.isDeposit ? 'Setor ke Tabungan' : 'Tarik dari Tabungan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info target
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.isDeposit
                    ? 'Setor ke: ${widget.goalTitle}'
                    : 'Tarik dari: ${widget.goalTitle}\nTerkumpul: Rp ${widget.currentAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
            // Pilih dompet
            walletsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Gagal memuat dompet: $e'),
              data: (wallets) => DropdownButtonFormField<String>(
                initialValue: _selectedWalletId,
                decoration: InputDecoration(
                  labelText: widget.isDeposit ? 'Dari Dompet' : 'Ke Dompet',
                  border: const OutlineInputBorder(),
                ),
                items: wallets
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text('${w.name} (Rp ${w.balance.toStringAsFixed(0)})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedWalletId = v),
              ),
            ),
            const SizedBox(height: 16),
            // Input nominal
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isDeposit ? 'Setor' : 'Tarik'),
        ),
      ],
    );
  }
}
```

---

## Langkah 14: Dialog AddEditSavingsGoalDialog

**Buat file:** `lib/src/features/savings/presentation/add_edit_savings_goal_dialog.dart`

```dart
import "package:flutter/material.dart";
import "package:flutter/services.dart";

// Dialog untuk membuat atau mengubah target tabungan.
// Pengguna memasukkan judul, nominal target, dan tanggal target (opsional).
class AddEditSavingsGoalDialog extends StatefulWidget {
  const AddEditSavingsGoalDialog({
    super.key,
    this.initialTitle,
    this.initialTargetAmount,
    this.initialTargetDate,
  });

  // Judul awal (untuk mode edit).
  final String? initialTitle;

  // Target nominal awal (untuk mode edit).
  final double? initialTargetAmount;

  // Tanggal target awal (untuk mode edit).
  final String? initialTargetDate;

  @override
  State<AddEditSavingsGoalDialog> createState() =>
      _AddEditSavingsGoalDialogState();
}

class _AddEditSavingsGoalDialogState extends State<AddEditSavingsGoalDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _amountController = TextEditingController(
      text: widget.initialTargetAmount?.toStringAsFixed(0) ?? '',
    );
    if (widget.initialTargetDate != null) {
      _targetDate = DateTime.tryParse(widget.initialTargetDate!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? get _formattedTargetDate {
    if (_targetDate == null) return null;
    return '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul harus diisi')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal target harus lebih dari 0')),
      );
      return;
    }

    Navigator.of(context).pop({
      'title': title,
      'targetAmount': amount,
      'targetDate': _formattedTargetDate,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialTitle != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Target Tabungan' : 'Target Tabungan Baru'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input judul
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Judul',
                hintText: 'Contoh: Dana Liburan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Input nominal target
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Target Nominal (Rp)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Pilih tanggal target (opsional)
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _targetDate != null
                    ? 'Target: $_formattedTargetDate'
                    : 'Pilih Tanggal Target (opsional)',
              ),
            ),
            if (_targetDate != null)
              TextButton(
                onPressed: () => setState(() => _targetDate = null),
                child: const Text('Hapus Tanggal'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
```

---

## Langkah 15: Halaman SavingsGoalListScreen

**Buat file:** `lib/src/features/savings/presentation/savings_goal_list_screen.dart`

```dart
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/savings_goal_providers.dart";
import "widgets/savings_goal_card.dart";
import "deposit_withdraw_goal_dialog.dart";
import "add_edit_savings_goal_dialog.dart";

// Halaman utama untuk menampilkan daftar semua target tabungan.
// Pengguna bisa menambah, mengedit, menghapus, menyetor, dan menarik dana.
class SavingsGoalListScreen extends ConsumerWidget {
  const SavingsGoalListScreen({super.key});

  void _openAddDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddEditSavingsGoalDialog(),
    );

    if (result != null) {
      await ref.read(savingsGoalListProvider.notifier).addSavingsGoal(
        title: result['title'] as String,
        targetAmount: result['targetAmount'] as double,
        targetDate: result['targetDate'] as String?,
      );
    }
  }

  void _openDepositWithdraw(
    BuildContext context,
    WidgetRef ref, {
    required String goalId,
    required String goalTitle,
    required bool isDeposit,
    required double currentAmount,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DepositWithdrawGoalDialog(
        goalTitle: goalTitle,
        isDeposit: isDeposit,
        currentAmount: currentAmount,
      ),
    );

    if (result != null) {
      final notifier = ref.read(savingsGoalListProvider.notifier);
      if (isDeposit) {
        await notifier.deposit(
          goalId: goalId,
          walletId: result['walletId'] as String,
          amount: result['amount'] as double,
        );
      } else {
        await notifier.withdraw(
          goalId: goalId,
          walletId: result['walletId'] as String,
          amount: result['amount'] as double,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Tabungan'),
        actions: [
          IconButton(
            onPressed: () => _openAddDialog(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Target Tabungan',
          ),
        ],
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat target tabungan: $e'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(savingsGoalListProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.savings_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Belum ada target tabungan'),
                  SizedBox(height: 4),
                  Text(
                    'Ketuk tombol + untuk membuat target baru',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(savingsGoalListProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                return SavingsGoalCard(
                  goal: goal,
                  onTap: () {
                    // Tampilkan pilihan setor atau tarik
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.add_circle_outline),
                              title: const Text('Setor ke Tabungan'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _openDepositWithdraw(
                                  context,
                                  ref,
                                  goalId: goal.id,
                                  goalTitle: goal.title,
                                  isDeposit: true,
                                  currentAmount: goal.currentAmount,
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.remove_circle_outline),
                              title: const Text('Tarik dari Tabungan'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _openDepositWithdraw(
                                  context,
                                  ref,
                                  goalId: goal.id,
                                  goalTitle: goal.title,
                                  isDeposit: false,
                                  currentAmount: goal.currentAmount,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onDelete: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hapus Target Tabungan?'),
                        content: Text('Hapus target "${goal.title}"?'),
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
                          .read(savingsGoalListProvider.notifier)
                          .removeSavingsGoal(goal.id);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
```

---

## Langkah 16: Jalankan Code Generation

Setelah semua file dibuat, jalankan perintah berikut di terminal dari folder `finance_tracker`:

```bash
dart run build_runner build
```

Tunggu hingga selesai. Pastikan tidak ada error.

---

## Langkah 17: Verifikasi

Jalankan analisis untuk memastikan tidak ada error:

```bash
flutter analyze
```

Harusnya menampilkan "No issues found!"

---

## Ringkasan File yang Dibuat

| No | File | Fungsi |
|----|------|--------|
| 1 | `budgeting/domain/budget.dart` | Model data anggaran + progres |
| 2 | `budgeting/data/budget_repository.dart` | Query database anggaran |
| 3 | `budgeting/providers/budget_providers.dart` | State management anggaran |
| 4 | `budgeting/presentation/widgets/budget_progress_bar.dart` | Widget bar progres warna |
| 5 | `budgeting/presentation/widgets/budget_card.dart` | Kartu anggaran per kategori |
| 6 | `budgeting/presentation/widgets/budget_warning_banner.dart` | Banner peringatan overbudget |
| 7 | `budgeting/presentation/set_budget_dialog.dart` | Dialog atur anggaran |
| 8 | `budgeting/presentation/budget_list_screen.dart` | Halaman daftar anggaran |
| 9 | `savings/domain/savings_goal.dart` | Model data target tabungan |
| 10 | `savings/data/savings_goal_repository.dart` | Query database target tabungan |
| 11 | `savings/providers/savings_goal_providers.dart` | State management target tabungan |
| 12 | `savings/presentation/widgets/savings_goal_card.dart` | Kartu target tabungan |
| 13 | `savings/presentation/deposit_withdraw_goal_dialog.dart` | Dialog setor/tarik dana |
| 14 | `savings/presentation/add_edit_savings_goal_dialog.dart` | Dialog buat/edit target |
| 15 | `savings/presentation/savings_goal_list_screen.dart` | Halaman daftar target tabungan |
