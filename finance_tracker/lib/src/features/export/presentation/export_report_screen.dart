import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../transactions/domain/transaction.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../data/csv_exporter_service.dart';
import '../data/pdf_report_generator_service.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengekspor CSV: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengekspor PDF: $e')));
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
