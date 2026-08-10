import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/budget_providers.dart";
import "set_budget_dialog.dart";
import "widgets/budget_card.dart";
import "widgets/budget_warning_banner.dart";

class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  List<String> _generateMonthOptions() {
    final now = DateTime.now();
    final months = <String>[];
    for (int i = -6; i <= 6; i++) {
      final date = DateTime(now.year, now.month + i);
      months.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }
    return months;
  }

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
}
