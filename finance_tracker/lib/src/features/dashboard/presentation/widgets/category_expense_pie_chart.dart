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

    return SizedBox(
      height: 220,
      child: Row(
        children: [
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
                    title: percent >= 5 ? '${percent.toStringAsFixed(0)}%' : '',
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
