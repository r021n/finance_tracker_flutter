import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../../transactions/domain/transaction.dart';

class CsvExporterService {
  String transactionsToCsv(List<Transaction> transactions) {
    final rows = <List<dynamic>>[
      ['Tanggal', 'Jenis', 'Jumlah', 'Catatan'],
    ];

    for (final t in transactions) {
      rows.add([
        t.transactionDate,
        t.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran',
        t.amount,
        t.note ?? '',
      ]);
    }

    final csv = Csv();
    return csv.encode(rows);
  }

  Future<File> saveCsvToFile(String csvString, String fileName) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString);
    return file;
  }
}
