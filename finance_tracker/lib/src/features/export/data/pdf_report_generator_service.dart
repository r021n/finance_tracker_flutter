import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../transactions/domain/transaction.dart';

class PdfReportGeneratorService {
  Future<pw.Document> generateReport({
    required String title,
    required List<Transaction> transactions,
    required String monthYear,
  }) async {
    final pdf = pw.Document();

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
            "Periode: $monthYear",
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 16),

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

          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
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
                    t.type == TransactionType.income
                        ? 'Pemasukan'
                        : 'Pengeluaran',
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

  Future<File> savePdfToFile(pw.Document pdf, String fileName) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _summaryItem(String label, double amount) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text(
          _formatAmount(amount),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

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
