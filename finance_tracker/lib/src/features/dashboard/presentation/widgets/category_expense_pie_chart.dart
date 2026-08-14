import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/color_utils.dart';
import '../../domain/dashboard_summary.dart';

class CategoryExpensePieChart extends StatelessWidget {
  const CategoryExpensePieChart({super.key, required this.data});

  final List<CategoryExpenseSummary> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Belum ada data pengeluaran')),
      );
    }

    final totalExpense = data.fold(0.0, (sum, item) => sum + item.total);

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
  }
}
